--[[
    Homestead - Event Sources
    Created: 2026-02-17
    Total entries: 16

    Maps itemID to seasonal/holiday event vendor source information.
    These items are only purchasable during their respective holiday events.

    Also defines EventVendors — vendor objects matching VendorDatabase schema,
    used by VendorData to inject event vendor pins when holidays are active.
]]

local _, HA = ...

-------------------------------------------------------------------------------
-- Event Definitions
-------------------------------------------------------------------------------

-- Each event has metadata used for display.
-- Holiday detection (eventID matching) is handled by CalendarDetector.
local EventDefinitions = {
    ["Lunar Festival"] = {},
    ["Noblegarden"] = {},
}

-------------------------------------------------------------------------------
-- Item-to-Event Source Mapping
-------------------------------------------------------------------------------

HA.EventSources = {
    -- Lunar Festival — Vendor: Valadar Starsong [15864], Moonglade
    -- Currency: Coin of Ancestry (itemID 21100)
    [253244] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253254] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253255] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253256] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253257] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253290] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253291] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253292] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253293] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253294] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253295] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253296] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},
    [253297] = {event = "Lunar Festival", vendorName = "Valadar Starsong", npcID = 15864, zone = "Moonglade", mapID = 80, x = 0.534, y = 0.353, currency = "Coin of Ancestry", currencyItemID = 21100},

    -- Noblegarden — Vendor: Noblegarden Merchant/Vendor (various NPCs per race zone)
    -- Currency: Noblegarden Chocolate (itemID 44791)
    [250794] = {event = "Noblegarden", vendorName = "Noblegarden Merchant", zone = "Starting Zones", currency = "Noblegarden Chocolate", currencyItemID = 44791},
    [250795] = {event = "Noblegarden", vendorName = "Noblegarden Merchant", zone = "Starting Zones", currency = "Noblegarden Chocolate", currencyItemID = 44791},
    [250796] = {event = "Noblegarden", vendorName = "Noblegarden Merchant", zone = "Starting Zones", currency = "Noblegarden Chocolate", currencyItemID = 44791},
}

-- Attach event definitions for CalendarDetector cross-reference
HA.EventSources.EventDefinitions = EventDefinitions

-------------------------------------------------------------------------------
-- Event Vendors (vendor-centric, matching VendorDatabase schema)
-- Injected into VendorData when their holiday is active.
-- Noblegarden omitted: multi-location vendors with no single canonical NPC ID.
-------------------------------------------------------------------------------

HA.EventSources.EventVendors = {
    [15864] = {
        npcID = 15864,
        name = "Valadar Starsong",
        mapID = 80,
        zone = "Moonglade",
        x = 0.534,
        y = 0.353,
        faction = "Neutral",
        event = "Lunar Festival",
        _isEventVendor = true,
        items = {253244, 253254, 253255, 253256, 253257, 253290, 253291, 253292, 253293, 253294, 253295, 253296, 253297},
    },
}

-- MapID index for EventVendors (mirrors VendorDatabase.ByMapID pattern)
HA.EventSources.EventVendorsByMapID = {}
for npcID, vendor in pairs(HA.EventSources.EventVendors) do
    local mapID = vendor.mapID
    if mapID then
        if not HA.EventSources.EventVendorsByMapID[mapID] then
            HA.EventSources.EventVendorsByMapID[mapID] = {}
        end
        table.insert(HA.EventSources.EventVendorsByMapID[mapID], vendor)
    end
end
