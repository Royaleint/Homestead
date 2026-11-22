--[[
    Homestead - Event Sources
    Created: 2026-02-17
    Total entries: 18

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
    ["Noblegarden"] = {},
    ["Brewfest"] = {},
    ["Hallow's End"] = {},
}

-------------------------------------------------------------------------------
-- Item-to-Event Source Mapping
-------------------------------------------------------------------------------

HA.EventSources = {
    -- Noblegarden — Vendor: Noblegarden Merchant/Vendor (various NPCs per race zone)
    -- Currency: Noblegarden Chocolate (itemID 44791)
    [250794] = {event = "Noblegarden", vendorName = "Noblegarden Merchant", zone = "Starting Zones", currency = "Noblegarden Chocolate", currencyItemID = 44791},
    [250795] = {event = "Noblegarden", vendorName = "Noblegarden Merchant", zone = "Starting Zones", currency = "Noblegarden Chocolate", currencyItemID = 44791},
    [250796] = {event = "Noblegarden", vendorName = "Noblegarden Merchant", zone = "Starting Zones", currency = "Noblegarden Chocolate", currencyItemID = 44791},

    -- Hallow's End — Vendors: Echo [273402], Jack [273403], Cordula Wolfgang [273472], Spew Gutsout [273470] (EventVendors below)
    [282192] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282194] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282196] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282198] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282200] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282202] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282204] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282206] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282208] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282213] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [282289] = {event = "Hallow's End", vendorName = "Hallow's End Vendor", zone = "Tirisfal Glades / Elwynn Forest / Founder's Point / Razorwind Shores"},
    [280337] = {event = "Brewfest", vendorName = "Fizz Alechux / Kay Stouthammer", zone = "Razorwind Shores / Founder's Point", currency = "Brewfest Prize Token", currencyItemID = 37829, notes = "Also sold by Dizzy Alechux and Fay Stouthammer at the Brewfest camps outside Orgrimmar and Ironforge."},
    [280339] = {event = "Brewfest", vendorName = "Fizz Alechux / Kay Stouthammer", zone = "Razorwind Shores / Founder's Point", currency = "Brewfest Prize Token", currencyItemID = 37829, notes = "Also sold by Dizzy Alechux and Fay Stouthammer at the Brewfest camps outside Orgrimmar and Ironforge."},
    [280341] = {event = "Brewfest", vendorName = "Fizz Alechux / Kay Stouthammer", zone = "Razorwind Shores / Founder's Point", currency = "Brewfest Prize Token", currencyItemID = 37829, notes = "Also sold by Dizzy Alechux and Fay Stouthammer at the Brewfest camps outside Orgrimmar and Ironforge."},
    [280343] = {event = "Brewfest", vendorName = "Fizz Alechux / Kay Stouthammer", zone = "Razorwind Shores / Founder's Point", currency = "Brewfest Prize Token", currencyItemID = 37829, notes = "Also sold by Dizzy Alechux and Fay Stouthammer at the Brewfest camps outside Orgrimmar and Ironforge."},
}

-- Attach event definitions for CalendarDetector cross-reference
HA.EventSources.EventDefinitions = EventDefinitions

-------------------------------------------------------------------------------
-- Event Vendors (vendor-centric, matching VendorDatabase schema)
-- Injected into VendorData when their holiday is active.
-- Noblegarden omitted: multi-location vendors with no single canonical NPC ID.
-- An entry whose wares are in VendorOffers carries no items key.
-------------------------------------------------------------------------------

HA.EventSources.EventVendors = {
    [273402] = { npcID = 273402, name = "Echo", mapID = 18, zone = "Tirisfal Glades", subzone = "Ruins of Lordaeron",
        x = 0.6232, y = 0.6674, faction = "Horde", event = "Hallow's End", _isEventVendor = true, scanConfirmed = "2026-10-19" },
    [273403] = { npcID = 273403, name = "Jack", mapID = 37, zone = "Elwynn Forest", subzone = "Stormwind Gate",
        x = 0.3197, y = 0.5029, faction = "Alliance", event = "Hallow's End", _isEventVendor = true, scanConfirmed = "2026-10-19" },
    [273472] = { npcID = 273472, name = "Cordula Wolfgang", mapID = 2352, zone = "Founder's Point",
        x = 0.5431, y = 0.327, event = "Hallow's End", _isEventVendor = true, scanConfirmed = "2026-10-19" },
    [273470] = { npcID = 273470, name = "Spew Gutsout", mapID = 2351, zone = "Razorwind Shores",
        x = 0.5241, y = 0.5441, event = "Hallow's End", _isEventVendor = true, scanConfirmed = "2026-10-19" },
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
