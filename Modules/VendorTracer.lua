--[[
    Homestead - VendorTracer Module
    Navigation system for finding vendors that sell housing decor

    Features:
    - Click-to-navigate: Click a decor item to get directions to vendor
    - Native WoW waypoints (supertracking)
    - TomTom integration (optional)
    - Vendor info panel showing items sold
]]

local addonName, HA = ...

-- Create VendorTracer module
local VendorTracer = {}
HA.VendorTracer = VendorTracer

-- Local references
local Constants = HA.Constants
local VendorData = HA.VendorData

-- Local state
local isInitialized = false
local currentWaypoint = nil
local tomtomUID = nil

-------------------------------------------------------------------------------
-- TomTom Integration
-------------------------------------------------------------------------------

local function IsTomTomAvailable()
    return TomTom and TomTom.AddWaypoint and TomTom.RemoveWaypoint
end

local function ClearTomTomWaypoint()
    if tomtomUID and IsTomTomAvailable() then
        TomTom:RemoveWaypoint(tomtomUID)
        tomtomUID = nil
    end
end

local function SetTomTomWaypoint(mapID, x, y, title)
    ClearTomTomWaypoint()

    if not IsTomTomAvailable() then
        return nil
    end

    -- TomTom uses 0-100 coordinates, we store 0-1
    local tomtomX = x * 100
    local tomtomY = y * 100

    tomtomUID = TomTom:AddWaypoint(mapID, tomtomX / 100, tomtomY / 100, {
        title = title or "Decor Vendor",
        persistent = false,
        minimap = true,
        world = true,
        from = "Homestead",
    })

    return tomtomUID
end

-------------------------------------------------------------------------------
-- Native Waypoint System (Supertracking)
-------------------------------------------------------------------------------

local function ClearNativeWaypoint()
    if C_SuperTrack then
        C_SuperTrack.ClearAllSuperTracked()
    end
    currentWaypoint = nil
end

local function SetNativeWaypoint(mapID, x, y, title)
    ClearNativeWaypoint()

    -- Create a user waypoint
    if C_Map and C_Map.SetUserWaypoint then
        if C_Map and C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
            return false
        end

        local mapPoint = UiMapPoint.CreateFromCoordinates(mapID, x, y)
        C_Map.SetUserWaypoint(mapPoint)

        -- Enable supertracking for the waypoint
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end

        currentWaypoint = {
            mapID = mapID,
            x = x,
            y = y,
            title = title,
        }

        return true
    end

    return false
end

-------------------------------------------------------------------------------
-- Public Navigation API
-------------------------------------------------------------------------------

-- Helper to get vendor coordinates (handles both old and new formats)
local function GetVendorXY(vendor)
    if not vendor then return nil, nil end
    -- New format: x, y directly
    if vendor.x and vendor.y then
        return vendor.x, vendor.y
    end
    -- Old format: coords table
    if vendor.coords then
        return vendor.coords.x, vendor.coords.y
    end
    return nil, nil
end

-- Navigate to a specific vendor
function VendorTracer:NavigateToVendor(npcID)
    if not VendorData then
        HA.Addon:Print("VendorData not available")
        return false
    end

    local vendor = VendorData:GetVendor(npcID)
    if not vendor then
        HA.Addon:Print("Vendor not found in database")
        return false
    end

    local x, y = GetVendorXY(vendor)
    if not x or not y then
        HA.Addon:Print("Vendor has no coordinates")
        return false
    end

    return self:SetWaypoint(vendor.mapID, x, y, vendor.name, vendor)
end

-- Navigate to the closest vendor selling an item
function VendorTracer:NavigateToItemVendor(itemID)
    if not VendorData then
        HA.Addon:Print("VendorData not available")
        return false
    end

    local vendor = VendorData:GetClosestVendorForItem(itemID)
    if not vendor then
        HA.Addon:Print("No vendor found selling this item")
        return false
    end

    local x, y = GetVendorXY(vendor)
    if not x or not y then
        HA.Addon:Print("Vendor has no coordinates")
        return false
    end

    -- Get item name for waypoint title
    local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
    local title = vendor.name .. " (" .. itemName .. ")"

    return self:SetWaypoint(vendor.mapID, x, y, title, vendor)
end

-- Set a waypoint to a location
function VendorTracer:SetWaypoint(mapID, x, y, title, vendorInfo)
    if not mapID or not x or not y then
        HA.Addon:Print("Invalid waypoint coordinates")
        return false
    end

    -- Delegate to Waypoints utility if available (respects user preferences)
    if HA.Waypoints then
        return HA.Waypoints:Set(mapID, x, y, {title = title or "Vendor"})
    end

    -- Fallback: Clear existing waypoints
    self:ClearWaypoint()

    local success = false
    local usedTomTom = false

    -- Check user preference for TomTom
    local vendorTracer = HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer
    local preferTomTom = vendorTracer and vendorTracer.useTomTom

    -- Try TomTom first if preferred and available
    if preferTomTom and IsTomTomAvailable() then
        if SetTomTomWaypoint(mapID, x, y, title) then
            success = true
            usedTomTom = true
        end
    end

    -- Set native waypoint if preferred
    local useNative = not vendorTracer or vendorTracer.useNativeWaypoints ~= false
    if useNative and SetNativeWaypoint(mapID, x, y, title) then
        success = true
    end

    if success then
        -- Get zone name for display
        local mapInfo = C_Map.GetMapInfo(mapID)
        local zoneName = mapInfo and mapInfo.name or "Unknown Zone"

        local coordStr = string.format("%.1f, %.1f", x * 100, y * 100)
        HA.Addon:Print("Waypoint set:", title or "Vendor")
        HA.Addon:Print("  Location:", zoneName, "(" .. coordStr .. ")")

        if usedTomTom then
            HA.Addon:Print("  (TomTom waypoint active)")
        end

        -- Show vendor info if available
        if vendorInfo then
            self:ShowVendorInfo(vendorInfo)
        end
    else
        HA.Addon:Print("Failed to set waypoint")
    end

    return success
end

-- Clear current waypoint
function VendorTracer:ClearWaypoint()
    ClearNativeWaypoint()
    ClearTomTomWaypoint()
end

-------------------------------------------------------------------------------
-- Vendor Info Display
-------------------------------------------------------------------------------

-- Show information about a vendor
function VendorTracer:ShowVendorInfo(vendor)
    if not vendor then return end

    -- Check if user wants verbose vendor info
    if HA.Addon and HA.Addon.db and not HA.Addon.db.profile.vendorTracer.showVendorDetails then
        return
    end

    if vendor.faction and vendor.faction ~= "Neutral" then
        HA.Addon:Print("  Faction:", vendor.faction)
    end

    if vendor.notes then
        HA.Addon:Print("  Note:", vendor.notes)
    end

    if vendor.seasonal then
        HA.Addon:Print("  Seasonal:", vendor.seasonal)
    end

    if vendor.limited then
        HA.Addon:Print("  (Limited stock)")
    end
end

-- Get vendors that sell items the player doesn't own
function VendorTracer:GetMissingItemVendors()
    if not VendorData then
        return {}
    end

    local result = {}
    local allVendors = VendorData:GetAllVendors()

    for _, vendor in ipairs(allVendors) do
        local missingItems = {}

        if vendor.items then
            -- Handle both formats: plain number or table with cost data
            for _, item in ipairs(vendor.items) do
                local itemID = HA.VendorData and HA.VendorData:GetItemID(item) or (type(item) == "number" and item or item[1])
                if itemID then
                    -- Check if player owns this item
                    local isOwned = false

                    if HA.DecorTracker then
                        isOwned = HA.DecorTracker:IsCollected(itemID)
                    elseif HA.CatalogStore then
                        isOwned = HA.CatalogStore:IsOwnedFresh(itemID)
                    end

                    if not isOwned then
                        table.insert(missingItems, {itemID = itemID})
                    end
                end
            end
        end

        if #missingItems > 0 then
            table.insert(result, {
                vendor = vendor,
                missingItems = missingItems,
                missingCount = #missingItems,
            })
        end
    end

    -- Sort by number of missing items (most first)
    table.sort(result, function(a, b)
        return a.missingCount > b.missingCount
    end)

    return result
end

-------------------------------------------------------------------------------
-- Item Click Handler
-------------------------------------------------------------------------------

-- Handle clicking on a decor item to navigate to vendor
function VendorTracer:OnDecorItemClick(itemID, button)
    if button ~= "LeftButton" then
        return false
    end

    -- Check if modifier key is held (for navigation)
    local navigateModifier = HA.Addon and HA.Addon.db and HA.Addon.db.profile.navigateModifier or "shift"

    local shouldNavigate = false
    if navigateModifier == "shift" and IsShiftKeyDown() then
        shouldNavigate = true
    elseif navigateModifier == "ctrl" and IsControlKeyDown() then
        shouldNavigate = true
    elseif navigateModifier == "alt" and IsAltKeyDown() then
        shouldNavigate = true
    elseif navigateModifier == "none" then
        shouldNavigate = true
    end

    if shouldNavigate then
        return self:NavigateToItemVendor(itemID)
    end

    return false
end

-------------------------------------------------------------------------------
-- Current Vendor Detection
-------------------------------------------------------------------------------

-- Check if the player is currently at a decor vendor
function VendorTracer:IsAtDecorVendor()
    -- Check if merchant frame is open
    if not MerchantFrame or not MerchantFrame:IsShown() then
        return false, nil
    end

    -- Get the current NPC's GUID and extract NPC ID
    local guid = UnitGUID("npc")
    if not guid then
        return false, nil
    end

    local npcID = select(6, strsplit("-", guid))
    npcID = tonumber(npcID)

    if not npcID then
        return false, nil
    end

    -- Check if this NPC is in our vendor database
    if VendorData then
        local vendor = VendorData:GetVendor(npcID)
        if vendor then
            return true, vendor
        end
    end

    return false, nil
end

-- Get items at current vendor that player doesn't own
function VendorTracer:GetMissingAtCurrentVendor()
    local isDecorVendor, vendor = self:IsAtDecorVendor()
    if not isDecorVendor or not vendor then
        return {}
    end

    local missingItems = {}

    if vendor.items then
        -- Handle both formats: plain number or table with cost data
        for _, item in ipairs(vendor.items) do
            local itemID = HA.VendorData and HA.VendorData:GetItemID(item) or (type(item) == "number" and item or item[1])
            if itemID then
                local isOwned = false

                if HA.DecorTracker then
                    isOwned = HA.DecorTracker:IsCollected(itemID)
                elseif HA.CatalogStore then
                    isOwned = HA.CatalogStore:IsOwnedFresh(itemID)
                end

                if not isOwned then
                    local itemName = GetItemInfo(itemID)
                    -- Get cost from item if available
                    local cost = HA.VendorData and HA.VendorData:GetItemCost(item) or (type(item) == "table" and item.cost)
                    table.insert(missingItems, {
                        itemID = itemID,
                        name = itemName,
                        cost = cost,
                        canAfford = nil,
                    })
                end
            end
        end
    end

    return missingItems
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorTracer:Initialize()
    if isInitialized then return end

    -- Initialize VendorData if available
    if VendorData and VendorData.Initialize then
        VendorData:Initialize()
    end

    -- Register for merchant events
    if HA.Addon then
        HA.Addon:RegisterEvent("MERCHANT_SHOW", function()
            VendorTracer:OnMerchantShow()
        end)
    end

    isInitialized = true

    if HA.Addon then
        HA.Addon:Debug("VendorTracer initialized")
        if IsTomTomAvailable() then
            HA.Addon:Debug("TomTom integration available")
        end
    end
end

-- Called when merchant window opens
function VendorTracer:OnMerchantShow()
    local isDecorVendor, vendor = self:IsAtDecorVendor()
    if not isDecorVendor then
        return
    end

    -- Clear any waypoint since we've arrived
    if currentWaypoint and vendor then
        -- Check if this is the vendor we were navigating to
        if currentWaypoint.title and currentWaypoint.title:find(vendor.name, 1, true) then
            self:ClearWaypoint()
            HA.Addon:Print("Arrived at", vendor.name)
        end
    end

    -- Show missing items notification
    local showNotification = HA.Addon and HA.Addon.db and HA.Addon.db.profile.showMissingAtVendor
    if showNotification ~= false then -- Default to true
        local missingItems = self:GetMissingAtCurrentVendor()
        if #missingItems > 0 then
            HA.Addon:Print("This vendor has", #missingItems, "decor item(s) you don't own!")
        end
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("VendorTracer", VendorTracer)
end
