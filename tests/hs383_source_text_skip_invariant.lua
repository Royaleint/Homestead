-- luacheck: globals assert loadfile _G string
-- HS-383: differential test proving CanSkipSourceTextLookup's skip decision
-- always matches whether a source-text lookup actually changes
-- ResolveVendorItemCost's outcome. Argus flagged that the hs355 fixtures never
-- populate a real scanned cost, so CanSkipSourceTextLookup always short-
-- circuited at its first `not scannedCost` check under test -- a logic
-- inversion on any other line would still ship green. This exercises every
-- `true`-returning exit directly against the resolver's real behavior.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")
local NOW = 2000000000
local DAY = 24 * 60 * 60

_G.time = function() return NOW end

local HA = {
    Addon = {
        RegisterModule = function() end,
        db = { global = { scannedVendors = {} } },
    },
    VendorOffers = {
        GeneratedBase = {},
        ManualOverrides = {},
        StagedAdditions = {},
        Tombstones = {},
    },
    VendorScanner = {
        GetCorrectedNPCID = function() return nil end,
    },
}

assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)

local vendor = { npcID = 1, name = "Test Vendor" }
local ITEM = 383383

local function CostsEqual(a, b)
    if a == b then return true end
    if not a or not b then return false end
    if a.gold ~= b.gold then return false end
    local aItems, bItems = a.items, b.items
    if (aItems == nil) ~= (bItems == nil) then return false end
    if aItems then
        if #aItems ~= #bItems then return false end
        for i, item in ipairs(aItems) do
            if item.itemID ~= bItems[i].itemID or item.amount ~= bItems[i].amount then
                return false
            end
        end
    end
    return true
end

-- sourceCost is always a gold-only, cheaper-than-scanned price when it could
-- matter -- the adversarial choice that WOULD flip the outcome via the
-- sourceText-discount branch (VendorData.lua's ResolveVendorItemCost) if
-- staleness/skip logic let it through when it shouldn't.
local SCANNED_SHAPES = {
    { name = "gold-only", cost = { gold = 1000 }, sourceCost = { gold = 500 } },
    { name = "mixed", cost = { gold = 1000, items = { { itemID = 1, amount = 2 } } },
        sourceCost = { gold = 1 } },
    { name = "nil", cost = nil, sourceCost = { gold = 42 } },
}

local STALENESS_STATES = {
    { name = "fresh-30d", scannedAt = NOW - (30 * DAY) },
    { name = "exactly-60d", scannedAt = NOW - (60 * DAY) },
    { name = "stale-61d", scannedAt = NOW - (61 * DAY) },
    { name = "nil-scannedAt", scannedAt = nil },
}

local caseCount = 0

for _, shape in ipairs(SCANNED_SHAPES) do
    for _, state in ipairs(STALENESS_STATES) do
        caseCount = caseCount + 1

        local scannedCost = shape.cost
        local scannedAt = state.scannedAt
        local sourceText = { cost = shape.sourceCost, lastParsed = NOW }

        local skip = HA.VendorData:CanSkipSourceTextLookup(scannedCost, scannedAt)

        local costWith, provWith = HA.VendorData:ResolveVendorItemCost(
            vendor, ITEM, sourceText, scannedCost, true, nil, true, scannedAt)
        local costWithout, provWithout = HA.VendorData:ResolveVendorItemCost(
            vendor, ITEM, nil, scannedCost, true, nil, true, scannedAt)

        local outcomesEqual = provWith == provWithout and CostsEqual(costWith, costWithout)

        assert(skip == outcomesEqual, string.format(
            "%s/%s: CanSkipSourceTextLookup=%s but outcomes-equal=%s "
                .. "(with=%s/%s, without=%s/%s)",
            shape.name, state.name, tostring(skip), tostring(outcomesEqual),
            tostring(provWith), tostring(costWith and costWith.gold),
            tostring(provWithout), tostring(costWithout and costWithout.gold)))
    end
end

assert(caseCount == 12, "expected 12 matrix cases, got " .. caseCount)

print("hs383_source_text_skip_invariant: ok (" .. caseCount .. " cases)")
