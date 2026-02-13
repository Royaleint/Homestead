--[[
    Homestead - DecorData
    Data class representing a housing decor item and its collection status
]]

local addonName, HA = ...

-- Create DecorData class
local DecorData = {}
DecorData.__index = DecorData
HA.DecorData = DecorData

-- Local references
local Constants = HA.Constants
local Cache = HA.Cache

-------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------

-- Create a new DecorData instance from an item link or ID
function DecorData:FromItemLink(itemLink)
    local self = setmetatable({}, DecorData)

    -- Initialize default values
    self.itemLink = itemLink
    self.itemID = nil
    self.entryID = nil
    self.name = nil
    self.icon = nil

    -- Ownership data
    self.isOwned = false
    self.quantityOwned = 0
    self.numPlaced = 0
    self.remainingRedeemable = 0

    -- Source information
    self.sourceType = Constants.SourceTypes.UNKNOWN
    self.sourceText = nil
    self.vendorInfo = nil

    -- Customization data
    self.canCustomize = false
    self.dyeSlots = {}
    self.customizations = nil

    -- Placement restrictions
    self.isAllowedIndoors = true
    self.isAllowedOutdoors = true

    -- Market info
    self.marketInfo = nil
    self.firstAcquisitionBonus = nil

    -- Populate data
    if itemLink then
        self:LoadFromItemLink(itemLink)
    end

    return self
end

-- Create a new DecorData instance from an item ID
function DecorData:FromItemID(itemID)
    local itemLink = "item:" .. itemID
    return DecorData:FromItemLink(itemLink)
end

-- Create a new DecorData instance from a catalog entry ID
function DecorData:FromEntryID(entryID)
    local self = setmetatable({}, DecorData)

    self.entryID = entryID
    self:LoadFromEntryID(entryID)

    return self
end

-------------------------------------------------------------------------------
-- Data Loading
-------------------------------------------------------------------------------

-- Load data from an item link using C_HousingCatalog API
function DecorData:LoadFromItemLink(itemLink)
    if not itemLink then return false end

    -- Extract item ID from link
    local itemID = GetItemInfoInstant(itemLink)
    if not itemID then return false end

    self.itemID = itemID
    self.itemLink = itemLink

    -- Check cache first
    local cachedData, isValid = Cache:GetDecorInfo(itemID)
    if isValid and cachedData then
        self:ApplyCachedData(cachedData)
        return true
    end

    -- Query the housing catalog API
    -- Note: This API may not be available outside of housing context
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
        end)
        if success and info then
            self:ApplyHousingCatalogInfo(info)
            -- Cache the result
            Cache:SetDecorInfo(itemID, self:ToCacheData())
            return true
        end
    end

    -- Fallback: Get basic item info
    self:LoadBasicItemInfo()

    return false
end

-- Load data from a catalog entry ID
function DecorData:LoadFromEntryID(entryID)
    if not entryID then return false end
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfo then
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfo(entryID, true)
        end)
        if success and info then
            self:ApplyHousingCatalogInfo(info)
            return true
        end
    end

    return false
end

-- Apply data from C_HousingCatalog.GetCatalogEntryInfoByItem result
function DecorData:ApplyHousingCatalogInfo(info)
    if not info then return end

    self.entryID = info.entryID
    self.itemID = info.itemID
    self.name = info.name

    -- Icon can be either iconTexture or iconAtlas
    if info.iconTexture then
        self.icon = info.iconTexture
    elseif info.iconAtlas then
        self.icon = info.iconAtlas
        self.iconIsAtlas = true
    end

    -- Ownership data - use entrySubtype to determine ownership
    -- entrySubtype is inside the entryID table, not at the top level!
    -- Enum.HousingCatalogEntrySubtype values (from live API):
    -- Invalid = 0
    -- Unowned = 1
    -- OwnedModifiedStack = 2
    -- OwnedUnmodifiedStack = 3

    -- Extract entrySubtype from the entryID table
    -- Note: The entryID object may be a Blizzard mixin that doesn't expose
    -- properties directly via info.entryID.entrySubtype, but does via pairs()
    local entrySubtype = nil
    local recordID = nil

    if info.entryID and type(info.entryID) == "table" then
        -- Try direct access first
        entrySubtype = info.entryID.entrySubtype
        recordID = info.entryID.recordID

        -- If direct access failed, iterate to find the values
        -- (Some Blizzard tables don't expose fields directly but do via pairs)
        if not entrySubtype or not recordID then
            for k, v in pairs(info.entryID) do
                if k == "entrySubtype" then
                    entrySubtype = v
                elseif k == "recordID" then
                    recordID = v
                end
            end
        end

        self.recordID = recordID
    end
    self.entrySubtype = entrySubtype

    self.quantityOwned = info.quantity or 0
    self.numPlaced = info.numPlaced or 0
    self.remainingRedeemable = info.remainingRedeemable or 0

    -- Primary ownership check: entrySubtype indicates owned (2 or 3)
    -- Note: There's a known Blizzard bug where items in storage may show as "Unowned" (1)
    local subtypeOwned = false
    if entrySubtype then
        if Enum and Enum.HousingCatalogEntrySubtype then
            -- Owned if it's OwnedModifiedStack (2) or OwnedUnmodifiedStack (3)
            subtypeOwned = (entrySubtype == Enum.HousingCatalogEntrySubtype.OwnedModifiedStack) or
                           (entrySubtype == Enum.HousingCatalogEntrySubtype.OwnedUnmodifiedStack)
        else
            -- Fallback: 2 or 3 = owned based on discovered enum values
            subtypeOwned = (entrySubtype >= 2)
        end
    end

    -- Fallback checks if entrySubtype says unowned
    -- firstAcquisitionBonus == 0 reliably detects ownership even when qty/placed are stale (post-reload)
    local quantityOwned = (self.quantityOwned > 0) or (self.numPlaced > 0) or (self.remainingRedeemable > 0)
        or (self.firstAcquisitionBonus == 0)

    -- Also check player's bags for this item
    local inBags = self:CheckItemInBags(self.itemID)

    -- Check persistent ownership cache (backup for performance)
    local cachedOwned = self:CheckPersistentOwnership(self.itemID)

    self.isOwned = subtypeOwned or quantityOwned or inBags or cachedOwned
    self.inBags = inBags
    self.cachedOwned = cachedOwned

    -- If we detected ownership through API, save to persistent cache
    if subtypeOwned or quantityOwned then
        self:SavePersistentOwnership(self.itemID, info.name, self.recordID)
    end

    -- Customization
    self.canCustomize = info.canCustomize or false
    self.customizations = info.customizations
    self.dyeSlots = info.dyeIDs or {}

    -- Placement restrictions
    self.isAllowedIndoors = info.isAllowedIndoors ~= false
    self.isAllowedOutdoors = info.isAllowedOutdoors ~= false

    -- Source and market info
    self.sourceText = info.sourceText
    self.marketInfo = info.marketInfo
    self.firstAcquisitionBonus = info.firstAcquisitionBonus

    -- Determine source type from sourceText or other indicators
    self:DetermineSourceType()
end

-- Load basic item info as fallback
function DecorData:LoadBasicItemInfo()
    if not self.itemLink then return end

    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(self.itemLink)
    if name then
        self.name = name
        self.icon = icon
    end
end

-- Apply cached data
function DecorData:ApplyCachedData(cached)
    for key, value in pairs(cached) do
        self[key] = value
    end
end

-- Convert to cache-friendly data
function DecorData:ToCacheData()
    return {
        itemID = self.itemID,
        entryID = self.entryID,
        name = self.name,
        icon = self.icon,
        iconIsAtlas = self.iconIsAtlas,
        isOwned = self.isOwned,
        quantityOwned = self.quantityOwned,
        numPlaced = self.numPlaced,
        sourceType = self.sourceType,
        sourceText = self.sourceText,
        canCustomize = self.canCustomize,
        isAllowedIndoors = self.isAllowedIndoors,
        isAllowedOutdoors = self.isAllowedOutdoors,
    }
end

-------------------------------------------------------------------------------
-- Source Type Determination
-------------------------------------------------------------------------------

function DecorData:DetermineSourceType()
    local sourceText = self.sourceText

    if not sourceText then
        self.sourceType = Constants.SourceTypes.UNKNOWN
        return
    end

    local lowerSource = sourceText:lower()

    -- Check for vendor indicators
    if lowerSource:find("vendor") or lowerSource:find("sold by") or lowerSource:find("purchase") then
        self.sourceType = Constants.SourceTypes.VENDOR
    -- Check for crafting indicators
    elseif lowerSource:find("craft") or lowerSource:find("profession") or lowerSource:find("recipe") then
        self.sourceType = Constants.SourceTypes.CRAFT
    -- Check for achievement indicators
    elseif lowerSource:find("achievement") then
        self.sourceType = Constants.SourceTypes.ACHIEVEMENT
    -- Check for quest indicators
    elseif lowerSource:find("quest") then
        self.sourceType = Constants.SourceTypes.QUEST
    -- Check for drop indicators
    elseif lowerSource:find("drop") or lowerSource:find("loot") then
        self.sourceType = Constants.SourceTypes.DROP
    -- Check for reputation indicators
    elseif lowerSource:find("reputation") or lowerSource:find("renown") then
        self.sourceType = Constants.SourceTypes.REPUTATION
    -- Check for event indicators
    elseif lowerSource:find("event") or lowerSource:find("holiday") then
        self.sourceType = Constants.SourceTypes.EVENT
    else
        self.sourceType = Constants.SourceTypes.UNKNOWN
    end
end

-------------------------------------------------------------------------------
-- Status Methods
-------------------------------------------------------------------------------

-- Get the collection status for display
function DecorData:GetStatus()
    if self.isOwned then
        if self.numPlaced > 0 then
            return "COLLECTED_PLACED"
        else
            return "COLLECTED"
        end
    else
        return "NOT_COLLECTED"
    end
end

-- Get the icon to display based on status
function DecorData:GetStatusIcon()
    local status = self:GetStatus()
    local icons = Constants.Icons

    if status == "COLLECTED" then
        return icons.COLLECTED
    elseif status == "COLLECTED_PLACED" then
        return icons.COLLECTED_PLACED
    else
        -- Not collected - show source-based icon
        return self:GetSourceIcon()
    end
end

-- Get icon based on source type
function DecorData:GetSourceIcon()
    local icons = Constants.Icons
    local sourceType = self.sourceType

    if sourceType == Constants.SourceTypes.VENDOR then
        return icons.PURCHASABLE
    elseif sourceType == Constants.SourceTypes.CRAFT then
        return icons.CRAFTABLE
    elseif sourceType == Constants.SourceTypes.ACHIEVEMENT then
        return icons.ACHIEVEMENT_REWARD
    elseif sourceType == Constants.SourceTypes.DROP then
        return icons.DROP_SOURCE
    elseif sourceType == Constants.SourceTypes.QUEST then
        return icons.QUEST_REWARD
    elseif sourceType == Constants.SourceTypes.REPUTATION then
        return icons.REPUTATION
    else
        return icons.NOT_COLLECTED
    end
end

-- Get the color for the status
function DecorData:GetStatusColor()
    local status = self:GetStatus()
    local colors = Constants.Colors

    if status == "COLLECTED" then
        return colors.COLLECTED
    elseif status == "COLLECTED_PLACED" then
        return colors.COLLECTED_PLACED
    else
        return colors.NOT_COLLECTED
    end
end

-------------------------------------------------------------------------------
-- Tooltip Text Generation
-------------------------------------------------------------------------------

-- Get tooltip text lines for this decor item
function DecorData:GetTooltipLines()
    local lines = {}
    local L = HA.L or {}

    -- Status line
    local status = self:GetStatus()
    local color = self:GetStatusColor()
    local statusText

    if status == "COLLECTED" then
        statusText = L["Collected"] or "Collected"
    elseif status == "COLLECTED_PLACED" then
        statusText = L["Collected (Placed)"] or "Collected (Placed)"
    else
        statusText = L["Not Collected"] or "Not Collected"
    end

    table.insert(lines, {
        text = statusText,
        color = color,
    })

    -- Quantity info (if owned)
    if self.isOwned and self.quantityOwned > 0 then
        local quantityText = string.format(L["Quantity owned: %d"] or "Quantity owned: %d", self.quantityOwned)
        table.insert(lines, {
            text = quantityText,
            color = Constants.Colors.COLLECTED,
        })
    end

    -- Placed info
    if self.numPlaced > 0 then
        local placedText = string.format(L["Currently placed: %d"] or "Currently placed: %d", self.numPlaced)
        table.insert(lines, {
            text = placedText,
            color = Constants.Colors.COLLECTED_PLACED,
        })
    end

    -- Source info (if not owned)
    if not self.isOwned and self.sourceText then
        table.insert(lines, {
            text = (L["Source:"] or "Source:") .. " " .. self.sourceText,
            color = Constants.Colors.VENDOR,
        })
    end

    -- Dye slots info
    if self.canCustomize and #self.dyeSlots > 0 then
        local dyeText = string.format("%s (%d)", L["Can be dyed"] or "Can be dyed", #self.dyeSlots)
        table.insert(lines, {
            text = dyeText,
            color = { r = 0.5, g = 0.5, b = 1.0, a = 1.0 },
        })
    end

    -- Placement restrictions
    if not self.isAllowedIndoors then
        table.insert(lines, {
            text = L["Outdoor only"] or "Outdoor only",
            color = { r = 1.0, g = 0.5, b = 0.0, a = 1.0 },
        })
    elseif not self.isAllowedOutdoors then
        table.insert(lines, {
            text = L["Indoor only"] or "Indoor only",
            color = { r = 1.0, g = 0.5, b = 0.0, a = 1.0 },
        })
    end

    return lines
end

-------------------------------------------------------------------------------
-- Utility Methods
-------------------------------------------------------------------------------

-- Check if an item is in the player's bags
function DecorData:CheckItemInBags(itemID)
    if not itemID then return false end

    -- Check all bag slots
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return true
            end
        end
    end

    -- Also check bank if available
    -- Bank bags are -1 (main bank) and 6-12 (bank bags)
    -- Note: Bank data may not be available if bank isn't open
    local bankBags = {-1, 6, 7, 8, 9, 10, 11, 12}
    for _, bag in ipairs(bankBags) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    return true
                end
            end
        end
    end

    return false
end

-- Check if this is a valid decor item
function DecorData:IsValid()
    return self.entryID ~= nil or (self.itemID ~= nil and self.name ~= nil)
end

-- Check if this decor item can be dyed
function DecorData:IsDyeable()
    return self.canCustomize and #self.dyeSlots > 0
end

-- Get the number of dye slots
function DecorData:GetDyeSlotCount()
    return #self.dyeSlots
end

-- Refresh data from API
function DecorData:Refresh()
    -- Clear cache for this item
    if self.itemID then
        Cache:Remove("decor", self.itemID)
    end

    -- Reload data
    if self.itemLink then
        self:LoadFromItemLink(self.itemLink)
    elseif self.entryID then
        self:LoadFromEntryID(self.entryID)
    end
end

-------------------------------------------------------------------------------
-- Persistent Ownership Cache (Workaround for Blizzard API Bug)
-------------------------------------------------------------------------------
-- The C_HousingCatalog API's quantity/numPlaced fields can be stale after /reload.
-- firstAcquisitionBonus == 0 handles this reliably, but we also cache ownership
-- data in SavedVariables as a backup and for performance.

-- Check if an item is marked as owned in our persistent cache
-- Delegates to CatalogStore (Phase 2)
function DecorData:CheckPersistentOwnership(itemID)
    if not itemID then return false end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwned(itemID)
    end
    return false
end

-- Save an item as owned in our persistent cache
-- Delegates to CatalogStore (Phase 2) — CatalogStore handles dual-write to ownedDecor
function DecorData:SavePersistentOwnership(itemID, name, recordID)
    if not itemID then return end
    if HA.CatalogStore then
        HA.CatalogStore:SetOwned(itemID, name, recordID)
    end
end

-- Remove an item from persistent ownership cache (for manual corrections)
function DecorData:RemovePersistentOwnership(itemID)
    if not itemID then return end
    if not HA.Addon or not HA.Addon.db then return end

    local ownedDecor = HA.Addon.db.global.ownedDecor
    if ownedDecor then
        ownedDecor[itemID] = nil
    end
end

-- Get persistent ownership cache stats
-- Delegates to CatalogStore (Phase 2)
function DecorData:GetPersistentCacheStats()
    if HA.CatalogStore then
        return { count = HA.CatalogStore:GetOwnedCount() }
    end
    return { count = 0 }
end

