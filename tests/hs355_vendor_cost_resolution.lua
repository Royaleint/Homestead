-- luacheck: globals assert loadfile loadstring print _G io

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")
local NOW = 2000000000
local DAY = 24 * 60 * 60
local NPC_STATIC = 990355
local NPC_SCANNED = 990356
local ITEM = 290355
local STATIC_ONLY_ITEM = 290357
local SCANNED_ONLY_ITEM = 290358

_G.time = function() return NOW end

local HA = {
    Constants = { Icons = {
        PURCHASABLE = "vendor",
        CRAFTABLE = "profession",
        ACHIEVEMENT_REWARD = "achievement",
        DROP_SOURCE = "drop",
        QUEST_REWARD = "quest",
        REPUTATION = "reputation",
    } },
    Addon = {
        RegisterModule = function() end,
        db = { global = { scannedVendors = {} } },
    },
    VendorOffers = {
        GeneratedBase = {
            [NPC_STATIC] = { [ITEM] = { price = 1000000 } },
        },
        ManualOverrides = {},
        StagedAdditions = {},
        Tombstones = {},
    },
    VendorScanner = {
        GetCorrectedNPCID = function() return NPC_SCANNED end,
    },
}

assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

local vendor = {
    npcID = NPC_STATIC,
    name = "Test Vendor",
    items = {
        {itemID = ITEM, cost = {gold = 1000000}},
        {itemID = STATIC_ONLY_ITEM, cost = {gold = 700000}},
    },
}

HA.Addon.db.global.scannedVendors[NPC_SCANNED] = {
    lastScanned = NOW - (30 * DAY),
    items = {
        {itemID = ITEM, price = 900000},
        {itemID = SCANNED_ONLY_ITEM},
    },
}

local cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, {
    cost = {gold = 800000},
    lastParsed = NOW,
})
assert(cost.gold == 900000 and provenance == "scanned", "fresh scan must win")

HA.Addon.db.global.scannedVendors[NPC_SCANNED].lastScanned = NOW - (61 * DAY)
cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, {
    cost = {gold = 800000},
    lastParsed = NOW,
})
assert(cost.gold == 800000 and provenance == "sourceText-discount",
    "stale scan must yield to lower newer source text")

HA.Addon.db.global.scannedVendors[NPC_SCANNED].lastScanned = NOW - (60 * DAY)
cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, {
    cost = {gold = 800000},
    lastParsed = NOW,
})
assert(cost.gold == 900000 and provenance == "scanned", "60-day scan is not yet stale")

HA.Addon.db.global.scannedVendors[NPC_SCANNED].lastScanned = NOW - (61 * DAY)
HA.Addon.db.global.scannedVendors[NPC_SCANNED].items = {{
    itemID = ITEM,
    price = 900000,
    itemCosts = {{itemID = 168327, amount = 5}},
}}
cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, {
    cost = {gold = 800000},
    lastParsed = NOW,
})
assert(cost.gold == 900000 and cost.items and cost.items[1].amount == 5
        and provenance == "scanned", "mixed scanned costs must not be discounted away")

HA.Addon.db.global.scannedVendors[NPC_SCANNED].items = {{itemID = ITEM}}
cost, provenance = HA.VendorData:ResolveVendorItemCost(vendor, ITEM, nil)
assert(cost.gold == 1000000 and provenance == "static", "missing scan cost must fall back to static")

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
HA.SourceTextScanner = {
    GetParsedSource = function()
        return {
            lastParsed = NOW,
            sources = {{sourceType = "vendor", name = "Test Vendor", cost = {gold = 800000}}},
        }
    end,
}
HA.VendorData.GetClosestVendorForItem = function() return vendor end
local source = HA.SourceManager:GetVendorSource(ITEM)
assert(source.cost.gold == 800000,
    "source manager vendor payload must use the shared resolver")

local pinSource = assert(io.open(root .. "/UI/VendorPinTooltips.lua", "r")):read("*a")
assert(pinSource:find("GetVendorItemCost", 1, true) ~= nil,
    "pin tooltip must call the shared vendor-cost resolver")
local gatherBody = pinSource:match(
    "%-%- Gather items from both static and scanned data\n(.-)\n    if #allItems > 0 then")
assert(gatherBody, "pin gather block must remain extractable")
local gatherItems = assert(loadstring(
    "local function Gather(vendor, HA, tinsert, itemDetailsEnabled)\n"
        .. gatherBody .. "\n    return allItems\nend\nreturn Gather"))()
local resolverCalls = 0
local scannedRecordReads = 0
HA.VendorData.GetItemsForVendor = function() return vendor.items end
local realGetVendorItemCost = HA.SourceManager.GetVendorItemCost
local realGetScannedVendorRecord = HA.VendorData.GetScannedVendorRecord
HA.VendorData.GetScannedVendorRecord = function(self, currentVendor)
    scannedRecordReads = scannedRecordReads + 1
    return realGetScannedVendorRecord(self, currentVendor)
end
HA.SourceManager.GetVendorItemCost = function(self, itemID, currentVendor,
        scannedCost, scannedCostKnown, staticCost, staticCostKnown, scannedAt)
    resolverCalls = resolverCalls + 1
    assert(scannedCostKnown == true, "pin gather must pass precomputed scan state")
    assert(staticCostKnown == true, "pin gather must pass precomputed static state")
    return realGetVendorItemCost(self, itemID, currentVendor, scannedCost,
        scannedCostKnown, staticCost, staticCostKnown, scannedAt)
end
HA.SourceTextScanner.GetParsedSource = function() return nil end
HA.Addon.db.global.scannedVendors[NPC_SCANNED].items = {
    {itemID = ITEM},
    {itemID = SCANNED_ONLY_ITEM},
}
local gathered = gatherItems(vendor, HA, table.insert, true)
assert(resolverCalls > 0 and scannedRecordReads == 1 and gathered[1].cost.gold == 1000000,
    "pin gather must execute the shared resolver with one scan read")
assert(gathered[2].cost.gold == 700000,
    "static-only pin rows must use the precomputed scan absence without rescanning")
assert(gathered[3].itemID == SCANNED_ONLY_ITEM and gathered[3].cost == nil,
    "costless scanned-only rows must use the precomputed static absence")

print("hs355_vendor_cost_resolution: ok")
