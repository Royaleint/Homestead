--[[
    Homestead - Cache
    Multi-tier caching system for API responses
]]

local addonName, HA = ...

-- Create cache module
local Cache = {}
HA.Cache = Cache

-- Local references for performance
local pairs = pairs
local ipairs = ipairs
local time = time
local wipe = wipe
local GetTime = GetTime

-- Constants
local Constants = HA.Constants

-------------------------------------------------------------------------------
-- Cache Storage
-------------------------------------------------------------------------------

-- Main cache storage with different tiers
local cacheData = {
    decor = {},       -- Decor item info cache
    vendor = {},      -- Vendor info cache
    dye = {},         -- Dye info cache
    source = {},      -- Item source cache
    general = {},     -- General purpose cache
}

-- Cache metadata (timestamps, hit counts)
local cacheMeta = {
    decor = {},
    vendor = {},
    dye = {},
    source = {},
    general = {},
}

-- Cache statistics
local cacheStats = {
    hits = 0,
    misses = 0,
    evictions = 0,
}

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------

-- Default TTL values (in seconds)
local DEFAULT_TTL = {
    decor = Constants.Cache and Constants.Cache.TTL_DECOR_INFO or 300,
    vendor = Constants.Cache and Constants.Cache.TTL_VENDOR_INFO or 3600,
    dye = Constants.Cache and Constants.Cache.TTL_DYE_INFO or 300,
    source = 600,
    general = 300,
}

-- Maximum cache entries per tier
local MAX_ENTRIES = Constants.Cache and Constants.Cache.MAX_ENTRIES or 1000

-------------------------------------------------------------------------------
-- Core Cache Functions
-------------------------------------------------------------------------------

-- Initialize the cache system
function Cache:Initialize()
    -- Register for events that should invalidate cache
    -- Note: Housing events may have different names or may not exist yet
    -- We'll use a safe registration approach
    if HA.Addon then
        -- Try to register housing events safely
        local housingEvents = {
            "HOUSING_CATALOG_UPDATED",
            "HOUSING_DECOR_PLACE_SUCCESS",
            "HOUSING_DECOR_REMOVE_SUCCESS",
        }

        for _, eventName in ipairs(housingEvents) do
            -- Use pcall to safely attempt registration
            local success = pcall(function()
                HA.Addon:RegisterEvent(eventName, function()
                    Cache:InvalidateTier("decor")
                end)
            end)
            if success then
                HA.Addon:Debug("Registered event:", eventName)
            end
        end

        -- Start maintenance timer
        Cache:StartMaintenanceTimer(60)
    end

    if HA.Addon then
        HA.Addon:Debug("Cache system initialized")
    end
end

-- Get a value from cache
-- Returns: value, isValid (nil if not found or expired)
function Cache:Get(tier, key)
    tier = tier or "general"
    local tierData = cacheData[tier]
    local tierMeta = cacheMeta[tier]

    if not tierData or not tierMeta then
        return nil, false
    end

    local value = tierData[key]
    local meta = tierMeta[key]

    if value == nil or meta == nil then
        cacheStats.misses = cacheStats.misses + 1
        return nil, false
    end

    -- Check if expired
    local currentTime = time()
    if meta.expires and currentTime > meta.expires then
        -- Entry expired, remove it
        self:Remove(tier, key)
        cacheStats.misses = cacheStats.misses + 1
        return nil, false
    end

    -- Update hit count and last access time
    meta.hits = (meta.hits or 0) + 1
    meta.lastAccess = currentTime
    cacheStats.hits = cacheStats.hits + 1

    return value, true
end

-- Set a value in cache
function Cache:Set(tier, key, value, ttl)
    tier = tier or "general"
    local tierData = cacheData[tier]
    local tierMeta = cacheMeta[tier]

    if not tierData or not tierMeta then
        return false
    end

    -- Check if we need to evict entries
    local count = self:GetTierCount(tier)
    if count >= MAX_ENTRIES then
        self:EvictOldest(tier, math.floor(MAX_ENTRIES * 0.1)) -- Evict 10%
    end

    -- Calculate expiration time
    ttl = ttl or DEFAULT_TTL[tier] or 300
    local currentTime = time()
    local expires = ttl > 0 and (currentTime + ttl) or nil

    -- Store value and metadata
    tierData[key] = value
    tierMeta[key] = {
        created = currentTime,
        lastAccess = currentTime,
        expires = expires,
        hits = 0,
    }

    return true
end

-- Remove a value from cache
function Cache:Remove(tier, key)
    tier = tier or "general"
    local tierData = cacheData[tier]
    local tierMeta = cacheMeta[tier]

    if tierData and tierMeta then
        tierData[key] = nil
        tierMeta[key] = nil
    end
end

-- Check if a key exists and is valid in cache
function Cache:Has(tier, key)
    local _, isValid = self:Get(tier, key)
    return isValid
end

-------------------------------------------------------------------------------
-- Tier Management
-------------------------------------------------------------------------------

-- Get the count of entries in a tier
function Cache:GetTierCount(tier)
    local count = 0
    local tierData = cacheData[tier]
    if tierData then
        for _ in pairs(tierData) do
            count = count + 1
        end
    end
    return count
end

-- Invalidate an entire cache tier
function Cache:InvalidateTier(tier)
    if cacheData[tier] then
        wipe(cacheData[tier])
        wipe(cacheMeta[tier])
        HA.Addon:Debug("Cache tier invalidated:", tier)
    end
end

-- Invalidate all cache tiers
function Cache:InvalidateAll()
    for tier in pairs(cacheData) do
        self:InvalidateTier(tier)
    end
    HA.Addon:Debug("All cache tiers invalidated")
end

-------------------------------------------------------------------------------
-- Eviction
-------------------------------------------------------------------------------

-- Evict oldest entries from a tier
function Cache:EvictOldest(tier, count)
    local tierData = cacheData[tier]
    local tierMeta = cacheMeta[tier]

    if not tierData or not tierMeta then
        return
    end

    -- Collect entries with their last access times
    local entries = {}
    for key, meta in pairs(tierMeta) do
        table.insert(entries, {
            key = key,
            lastAccess = meta.lastAccess or 0,
        })
    end

    -- Sort by last access time (oldest first)
    table.sort(entries, function(a, b)
        return a.lastAccess < b.lastAccess
    end)

    -- Remove oldest entries
    for i = 1, math.min(count, #entries) do
        local key = entries[i].key
        tierData[key] = nil
        tierMeta[key] = nil
        cacheStats.evictions = cacheStats.evictions + 1
    end

    HA.Addon:Debug("Evicted", count, "entries from cache tier:", tier)
end

-- Evict expired entries from a tier
function Cache:EvictExpired(tier)
    local tierData = cacheData[tier]
    local tierMeta = cacheMeta[tier]

    if not tierData or not tierMeta then
        return
    end

    local currentTime = time()
    local evicted = 0

    for key, meta in pairs(tierMeta) do
        if meta.expires and currentTime > meta.expires then
            tierData[key] = nil
            tierMeta[key] = nil
            evicted = evicted + 1
            cacheStats.evictions = cacheStats.evictions + 1
        end
    end

    if evicted > 0 then
        HA.Addon:Debug("Evicted", evicted, "expired entries from cache tier:", tier)
    end

    return evicted
end

-- Evict expired entries from all tiers
function Cache:EvictAllExpired()
    local total = 0
    for tier in pairs(cacheData) do
        total = total + (self:EvictExpired(tier) or 0)
    end
    return total
end

-------------------------------------------------------------------------------
-- Convenience Functions for Specific Data Types
-------------------------------------------------------------------------------

-- Cache decor info
function Cache:GetDecorInfo(itemID)
    return self:Get("decor", itemID)
end

function Cache:SetDecorInfo(itemID, info)
    return self:Set("decor", itemID, info)
end

-- Cache vendor info
function Cache:GetVendorInfo(npcID)
    return self:Get("vendor", npcID)
end

function Cache:SetVendorInfo(npcID, info)
    return self:Set("vendor", npcID, info)
end

-- Cache dye info
function Cache:GetDyeInfo(dyeID)
    return self:Get("dye", dyeID)
end

function Cache:SetDyeInfo(dyeID, info)
    return self:Set("dye", dyeID, info)
end

-- Cache item source info
function Cache:GetSourceInfo(itemID)
    return self:Get("source", itemID)
end

function Cache:SetSourceInfo(itemID, info)
    return self:Set("source", itemID, info)
end

-------------------------------------------------------------------------------
-- Statistics
-------------------------------------------------------------------------------

function Cache:GetStats()
    local stats = {
        hits = cacheStats.hits,
        misses = cacheStats.misses,
        evictions = cacheStats.evictions,
        hitRate = 0,
        tiers = {},
    }

    local total = stats.hits + stats.misses
    if total > 0 then
        stats.hitRate = (stats.hits / total) * 100
    end

    for tier in pairs(cacheData) do
        stats.tiers[tier] = self:GetTierCount(tier)
    end

    return stats
end

function Cache:ResetStats()
    cacheStats.hits = 0
    cacheStats.misses = 0
    cacheStats.evictions = 0
end

-------------------------------------------------------------------------------
-- Periodic Maintenance
-------------------------------------------------------------------------------

-- Run periodic maintenance (call this from a timer)
function Cache:RunMaintenance()
    self:EvictAllExpired()
end

-- Start automatic maintenance timer
function Cache:StartMaintenanceTimer(interval)
    interval = interval or 60 -- Default: every 60 seconds

    C_Timer.NewTicker(interval, function()
        Cache:RunMaintenance()
    end)
end
