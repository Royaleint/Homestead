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
assert(source.cost.gold == 1000000,
    "source manager vendor payload must use the shared resolver, shipped price over source text")

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
local realGetItemsForVendor = HA.VendorData.GetItemsForVendor
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
local parsedSourceReads = 0
HA.SourceTextScanner.GetParsedSource = function(_, itemID)
    parsedSourceReads = parsedSourceReads + 1
    if itemID == SCANNED_ONLY_ITEM then return nil end
    return {
        lastParsed = NOW,
        sources = {{sourceType = "vendor", name = "Test Vendor", cost = {gold = 800000}}},
    }
end
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
assert(parsedSourceReads == 1,
    "only the scanned-only row with no shipped price may read source text")

-- HS-485: shipped price outranks catalog source text for an unscanned vendor.
local NPC_SHIPPED = 990485
local CURRENCY_ITEM = 290485
local GOLD_ITEM = 290486
local COSTLESS_ITEM = 290487
local UNSHIPPED_ITEM = 290488
local shippedVendor = {npcID = NPC_SHIPPED, name = "Shipped Vendor"}

HA.SourceManager.GetVendorItemCost = realGetVendorItemCost
HA.VendorData.GetScannedVendorRecord = realGetScannedVendorRecord
HA.VendorData.GetItemsForVendor = realGetItemsForVendor
HA.Addon.db.global.scannedVendors[NPC_SCANNED] = nil
HA.VendorOffers.GeneratedBase[NPC_SHIPPED] = {
    [CURRENCY_ITEM] = {currencies = {{id = 1220, amount = 500}}},
    [GOLD_ITEM] = {price = 1500000},
    [COSTLESS_ITEM] = {price = 0},
}
HA.VendorOffers.ManualOverrides[NPC_SHIPPED] = {
    [CURRENCY_ITEM] = {currencies = {{id = 1220, amount = 150}}, costBuild = "12.1.0.69933"},
}
local sourceTextCosts = {
    [CURRENCY_ITEM] = {currencies = {{id = 1220, amount = 500}}},
    [GOLD_ITEM] = {gold = 2000000},
    [COSTLESS_ITEM] = {gold = 300000},
    [UNSHIPPED_ITEM] = {gold = 400000},
}
HA.SourceTextScanner.GetParsedSource = function(_, itemID)
    parsedSourceReads = parsedSourceReads + 1
    return {
        lastParsed = NOW,
        sources = {{sourceType = "vendor", name = "Shipped Vendor", cost = sourceTextCosts[itemID]}},
    }
end
parsedSourceReads = 0

cost, provenance = HA.SourceManager:GetVendorItemCost(CURRENCY_ITEM, shippedVendor)
assert(provenance == "static" and cost.currencies[1].id == 1220
        and cost.currencies[1].amount == 150,
    "shipped override price must outrank source text")
cost, provenance = HA.SourceManager:GetVendorItemCost(GOLD_ITEM, shippedVendor)
assert(provenance == "static" and cost.gold == 1500000,
    "shipped gold price must outrank source text")
assert(parsedSourceReads == 0, "a shipped price must skip the source-text lookup")

cost, provenance = HA.SourceManager:GetVendorItemCost(COSTLESS_ITEM, shippedVendor)
assert(provenance == "sourceText" and cost.gold == 300000,
    "a shipped row without a price must fall through to source text")
cost, provenance = HA.SourceManager:GetVendorItemCost(UNSHIPPED_ITEM, shippedVendor)
assert(provenance == "sourceText" and cost.gold == 400000,
    "an item with no shipped row must use source text")
assert(parsedSourceReads == 2, "only rows without a shipped price may read source text")

local offerRows = gatherItems(shippedVendor, HA, table.insert, true)
assert(#offerRows == 3, "pin gather must list each offers row once")
assert(offerRows[1].itemID == CURRENCY_ITEM and offerRows[1].cost.currencies[1].amount == 150,
    "pin gather must show the overridden shipped price")
assert(offerRows[2].itemID == GOLD_ITEM and offerRows[2].cost.gold == 1500000,
    "pin gather must show the shipped gold price")
assert(offerRows[3].itemID == COSTLESS_ITEM and offerRows[3].cost.gold == 300000,
    "pin gather must fall back to source text for a row without a shipped price")
assert(parsedSourceReads == 3, "pin gather may read source text only for the costless row")

cost, provenance = HA.VendorData:ResolveVendorItemCost(shippedVendor, GOLD_ITEM,
    {cost = {gold = 2000000}, lastParsed = NOW}, nil, true, {gold = 1500000}, true)
assert(provenance == "static" and cost.gold == 1500000,
    "resolver must rank a supplied shipped cost above source text")
cost, provenance = HA.VendorData:ResolveVendorItemCost(shippedVendor, GOLD_ITEM,
    {cost = {gold = 2000000}, lastParsed = NOW}, nil, true, nil, true)
assert(provenance == "sourceText" and cost.gold == 2000000,
    "a known-absent shipped price must still reach source text")

HA.VendorData.GetClosestVendorForItem = function() return shippedVendor end
HA.VendorData.GetVendorsForItem = function() return {shippedVendor} end
assert(HA.SourceManager:GetVendorSource(CURRENCY_ITEM).cost.currencies[1].amount == 150,
    "closest-vendor payload must carry the shipped price")
assert(HA.SourceManager:GetVendorSources(GOLD_ITEM)[1].data.cost.gold == 1500000,
    "all-vendors payload must carry the shipped price")

-- The scan is found through the GetCorrectedNPCID stub, which maps every name to NPC_SCANNED.
HA.Addon.db.global.scannedVendors[NPC_SCANNED] = {
    lastScanned = NOW - DAY,
    items = {{itemID = CURRENCY_ITEM, currencies = {{currencyID = 1220, amount = 120}}}},
}
cost, provenance = HA.SourceManager:GetVendorItemCost(CURRENCY_ITEM, shippedVendor)
assert(provenance == "scanned" and cost.currencies[1].amount == 120,
    "a scan must still outrank the shipped price")

-- Same stub as above: the scan is found through GetCorrectedNPCID.
HA.Addon.db.global.scannedVendors[NPC_SCANNED] = {
    lastScanned = NOW - (61 * DAY),
    items = {{itemID = GOLD_ITEM, price = 2100000}},
}
cost, provenance = HA.SourceManager:GetVendorItemCost(GOLD_ITEM, shippedVendor)
assert(provenance == "sourceText-discount" and cost.gold == 2000000,
    "a stale gold scan must still yield to lower newer source text")


-- A vendor carrying its own positional item list takes that list's price over
-- the offers table for the same npc and item.
HA.Addon.db.global.scannedVendors[NPC_SCANNED] = nil
local ownListVendor = {
    npcID = NPC_SHIPPED,
    name = "Shipped Vendor",
    items = {
        {GOLD_ITEM, cost = {gold = 1234000}},
        {COSTLESS_ITEM},
    },
}
cost, provenance = HA.SourceManager:GetVendorItemCost(GOLD_ITEM, ownListVendor)
assert(provenance == "static" and cost.gold == 1234000,
    "a vendor's own item list price must outrank both source text and the offers table")
cost, provenance = HA.SourceManager:GetVendorItemCost(COSTLESS_ITEM, ownListVendor)
assert(provenance == "sourceText" and cost.gold == 300000,
    "a bare row on a vendor's own item list must fall through to source text")

print("hs355_vendor_cost_resolution: ok")
