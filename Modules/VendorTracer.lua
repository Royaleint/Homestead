--[[
    Homestead - VendorTracer Module
    Navigation system for finding vendors that sell housing decor

    Features:
    - Click-to-navigate: Click a decor item to get directions to vendor
    - Native WoW waypoints (supertracking)
    - TomTom integration (optional)
    - Vendor info panel showing items sold
]]

local _, HA = ...

local VendorTracer = {}
HA.VendorTracer = VendorTracer

-- Local references
local VendorData = HA.VendorData

-- Local state
local isInitialized = false

-------------------------------------------------------------------------------
-- TomTom Availability
-------------------------------------------------------------------------------

-- HS-218: the rest of this module's own TomTom/native waypoint
-- implementation (SetTomTomWaypoint/ClearTomTomWaypoint/SetNativeWaypoint/
-- ClearNativeWaypoint + the currentWaypoint/tomtomUID locals) was dead code
-- — SetWaypoint below always delegates to HA.Waypoints when it's available,
-- and HA.Waypoints is always loaded (Utils/waypoints.lua is unconditionally
-- part of the TOC), so the "Fallback" branch that populated those locals
-- never actually ran. Worse, its ClearNativeWaypoint called
-- C_SuperTrack.ClearAllSuperTracked() — which cancels the player's own
-- tracked QUEST too, not just our vendor waypoint. Deleted rather than
-- repaired; only IsTomTomAvailable survives, still used by Initialize()'s
-- startup Debug log below.
local function IsTomTomAvailable()
    return TomTom and TomTom.AddWaypoint and TomTom.RemoveWaypoint
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
    local itemName = C_Item.GetItemInfo(itemID) or ("Item " .. itemID)
    local title = vendor.name .. " (" .. itemName .. ")"

    return self:SetWaypoint(vendor.mapID, x, y, title, vendor)
end

-- Set a waypoint to a location. Delegates to the Waypoints utility, which is
-- always loaded (Utils/waypoints.lua is unconditionally part of the TOC) and
-- respects the user's TomTom/native preferences itself. HS-218: data.npcID
-- is threaded through so OnMerchantShow's arrival-check below can confirm
-- the waypoint we're clearing on arrival is actually the one for THIS
-- vendor, not just "a" waypoint.
function VendorTracer:SetWaypoint(mapID, x, y, title, vendorInfo)
    if not mapID or not x or not y then
        HA.Addon:Print("Invalid waypoint coordinates")
        return false
    end

    if not HA.Waypoints then
        HA.Addon:Print("Failed to set waypoint")
        return false
    end

    local success = HA.Waypoints:Set(mapID, x, y, {
        title = title or "Vendor",
        data = vendorInfo and { npcID = vendorInfo.npcID } or nil,
    })

    if success then
        if vendorInfo then
            self:ShowVendorInfo(vendorInfo)
        end
    else
        HA.Addon:Print("Failed to set waypoint")
    end

    return success
end

-- Clear current waypoint — delegates to the Waypoints utility (see
-- SetWaypoint above for why the module no longer maintains its own
-- TomTom/native waypoint state).
function VendorTracer:ClearWaypoint()
    if HA.Waypoints then
        HA.Waypoints:Clear()
    end
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
    local CS = HA.CatalogStore

    for _, vendor in ipairs(allVendors) do
        local missingItems = {}

        local vendorItems = HA.VendorData.GetItemsForVendor and HA.VendorData:GetItemsForVendor(vendor) or {}
        for _, item in ipairs(vendorItems) do
            local itemID = HA.VendorData:GetItemID(item)
            if itemID then
                -- HS-249: this derives its own ownership rather than reading
                -- BadgeCalculation, so it needs its own exclusion guard.
                -- Housing items outside the Decor subclass resolve to no
                -- catalog entry, so IsOwnedFresh answers a hard false for them
                -- and every room plan on the vendor would be reported as
                -- missing. Leave them out until Phase 2 can resolve ownership.
                local ownershipExcluded = CS and CS.IsOwnershipUnknowable
                    and CS:IsOwnershipUnknowable(itemID)

                if not ownershipExcluded then
                    -- Check if player owns this item
                    local isOwned = CS and CS:IsOwnedFresh(itemID)

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

    -- Check if modifier key is held (for navigation). HS-218: this read a
    -- top-level profile.navigateModifier key nothing ever writes — the
    -- actual setting lives at profile.vendorTracer.navigateModifier
    -- (Core/constants.lua default, UI/OptionsModel.lua's get/set) — so a
    -- user-configured ctrl/alt/none never applied; every click silently
    -- behaved as if "shift" were selected.
    local vendorTracerSettings = HA.Addon and HA.Addon.db and HA.Addon.db.profile.vendorTracer
    local navigateModifier = (vendorTracerSettings and vendorTracerSettings.navigateModifier) or "shift"

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

    -- UnitGUID can be a restricted "secret string" in instanced contexts.
    -- Guard parsing so GUID matching cannot hard-error.
    local ok, npcIDText = pcall(string.match, guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    local npcID = ok and tonumber(npcIDText) or nil

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

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function VendorTracer:Initialize()
    if isInitialized then return end

    -- Initialize VendorData if available
    if VendorData and VendorData.Initialize then
        VendorData:Initialize()
    end

    -- Register for merchant events via a module-owned Foundry.Events controller.
    -- This is the live MERCHANT_SHOW handler (under AceEvent it won last-write-wins
    -- over core's, which never fired). A separate controller preserves that: core
    -- no longer registers MERCHANT_SHOW, so only this handler fires. Held on the
    -- module so the controller is not garbage-collected.
    local F = _G.Foundry_1_0
    VendorTracer.events = F.Events:New("Homestead.VendorTracer")
    VendorTracer.events:Register("MERCHANT_SHOW", function(event, ...)
        VendorTracer:OnMerchantShow()
    end)

    isInitialized = true

    if HA.Addon then
        HA.Addon:Debug("VendorTracer initialized")
        if IsTomTomAvailable() then
            HA.Addon:Debug("TomTom integration available")
        end
    end
end

function VendorTracer:OnMerchantShow()
    local isDecorVendor, vendor = self:IsAtDecorVendor()
    if not isDecorVendor then
        return
    end

    -- HS-218: currentWaypoint (this module's own local) was only ever
    -- populated by the dead SetNativeWaypoint fallback removed above — this
    -- check never actually fired in production. Consult the Waypoints
    -- utility's real current waypoint instead, matched by npcID (threaded
    -- through via SetWaypoint's data.npcID option) rather than a fragile
    -- title substring match.
    local waypoint = HA.Waypoints and HA.Waypoints:GetCurrent()
    if waypoint and vendor and waypoint.data and waypoint.data.npcID == vendor.npcID then
        self:ClearWaypoint()
        HA.Addon:Print("Arrived at", vendor.name)
    end
end

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

-- Register with main addon when it's ready
if HA.Addon then
    HA.Addon:RegisterModule("VendorTracer", VendorTracer)
end
