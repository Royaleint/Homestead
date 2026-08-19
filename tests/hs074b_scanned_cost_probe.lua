-- luacheck: globals assert loadfile loadstring print io table

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-074B: vendor-pin tooltip cost column showed "?" for scanned-vendor items.
-- Static items reach AddPinTooltipItemLine already carrying {cost = {...}} in
-- VendorData's normalized shape; scanned items were pushed onto allItems
-- verbatim, so their legacy {price, currencies} shape never matched
-- FormatCost's expected input and always fell to "?". The fix normalizes
-- scanned-item cost at the gather site (ShowVendorTooltip's allItems build,
-- UI/VendorPinTooltips.lua) via VendorData:NormalizeScannedCost, which
-- already existed and already handled this exact shape.
--
-- This test extracts the REAL gather block (the "Gather items from both
-- static and scanned data" section of ShowVendorTooltip) as a standalone
-- function and runs it against the real VendorData:NormalizeScannedCost and
-- FormatCost, rather than reimplementing the logic -- so it pins the actual
-- shipped code, not a paraphrase of it.
-------------------------------------------------------------------------------

local function extractGatherFn(sourceText)
    local body = sourceText:match(
        "%-%- Gather items from both static and scanned data\n(.-)\n    end\n\n    if #allItems > 0 then")
    assert(body ~= nil, "could not locate the allItems gather block in VendorPinTooltips.lua")

    local chunk = "local function GatherAllItems(vendor, HA, tinsert)\n"
        .. body .. "\n    end\n"
        .. "    return allItems\nend\nreturn GatherAllItems"
    return assert(loadstring(chunk, "GatherAllItems-extract"))()
end

local pinTooltipSource = assert(io.open(root .. "/UI/VendorPinTooltips.lua", "r")):read("*a")

-- Confirm the fix is wired at the gather site, not smuggled into the render
-- call (AddPinTooltipItemLine's FormatCost call must stay untouched).
assert(pinTooltipSource:find("HA%.VendorData:NormalizeScannedCost%(item%)", 1) ~= nil,
    "scanned-item gather must call VendorData:NormalizeScannedCost")

-------------------------------------------------------------------------------
-- Fixture: real VendorData.lua (real NormalizeScannedCost + FormatCost +
-- GetItemID/GetItemCost), a vendor with one static item, and three scanned
-- items covering gold price, currency price, and no price at all.
-------------------------------------------------------------------------------

local function freshHA()
    local HA = { Addon = { RegisterModule = function() end } }
    assert(loadfile(root .. "/Data/VendorData.lua"))("Homestead", HA)
    -- Isolate the gather test from the real static-item lookup path (HS-281
    -- memoization, VendorDatabase, etc.) -- GetItemsForVendor is mocked to
    -- hand back vendor.items directly; GetItemID/GetItemCost (UnpackItem)
    -- underneath are the real, unmodified functions.
    HA.VendorData.GetItemsForVendor = function(_, vendor) return vendor.items or {} end
    return HA
end

local NPC_ID = 990001

local function buildVendor()
    return {
        npcID = NPC_ID,
        items = {
            { itemID = 100, cost = { gold = 500 } }, -- static, pre-normalized
        },
    }
end

local function buildScannedVendors()
    return {
        [NPC_ID] = {
            items = {
                { itemID = 201, name = "Scanned Gold Item", price = 12345 },
                { itemID = 202, name = "Scanned Currency Item",
                    currencies = { { currencyID = 1220, amount = 50, name = "Trader's Tender" } } },
                { itemID = 203, name = "Scanned No Price Item" },
                -- Cycle-2 (Argus REJECT): corpus-realistic mixed money + item-token
                -- record, matching the shape VendorScanner/ScanPersistence persist
                -- for a record like [246480] (price=8000000, two 5-count itemCosts).
                { itemID = 300, name = "Scanned Mixed Cost Item", price = 8000000,
                    itemCosts = {
                        { itemID = 168327, amount = 5, name = "Trader's Tender" },
                        { itemID = 168832, amount = 5, name = "Radiant Fragment" },
                    } },
                -- Item-token cost only, no money and no Blizzard currency.
                { itemID = 301, name = "Scanned ItemCost-Only Item",
                    itemCosts = { { itemID = 168327, amount = 3, name = "Trader's Tender" } } },
            },
        },
    }
end

-------------------------------------------------------------------------------
-- 1. Behavioral check against the real (fixed) code.
-------------------------------------------------------------------------------

local GatherAllItems = extractGatherFn(pinTooltipSource)

local HA = freshHA()
HA.Addon.db = { global = { scannedVendors = buildScannedVendors() } }

local allItems = GatherAllItems(buildVendor(), HA, table.insert)
assert(#allItems == 6, "expected 1 static + 5 scanned items, got " .. #allItems)

local byID = {}
for _, item in ipairs(allItems) do byID[item.itemID] = item end

-- Case 1: static item cost unchanged.
assert(byID[100].cost.gold == 500)

-- Case 2: scanned item with gold price normalizes and renders (not "?").
assert(byID[201].cost ~= nil, "scanned gold-price item must carry a normalized cost")
assert(byID[201].cost.gold == 12345)

-- Case 3: scanned item with currency price normalizes and renders like static currency.
assert(byID[202].cost ~= nil, "scanned currency-price item must carry a normalized cost")
assert(byID[202].cost.currencies[1].id == 1220)
assert(byID[202].cost.currencies[1].amount == 50)

-- Case 4: scanned item with genuinely no price data still has no cost (never fabricated).
assert(byID[203].cost == nil, "scanned item with no price data must not fabricate a cost")

-- Case 5 (cycle 2): mixed money + item-token record carries BOTH components.
-- Argus's REJECT proved this understated price silently (gold rendered,
-- item-tokens dropped) rather than the honest "?" the pre-HS-074B code gave.
assert(byID[300].cost ~= nil, "mixed-cost scanned item must carry a normalized cost")
assert(byID[300].cost.gold == 8000000)
assert(byID[300].cost.items ~= nil, "mixed-cost scanned item must carry itemCosts as cost.items")
assert(#byID[300].cost.items == 2)
assert(byID[300].cost.items[1].id == 168327 and byID[300].cost.items[1].amount == 5)
assert(byID[300].cost.items[2].id == 168832 and byID[300].cost.items[2].amount == 5)

-- Case 6 (cycle 2): item-token-only record (no money, no Blizzard currency) renders too.
assert(byID[301].cost ~= nil, "itemCosts-only scanned item must carry a normalized cost")
assert(byID[301].cost.items ~= nil)
assert(byID[301].cost.items[1].id == 168327 and byID[301].cost.items[1].amount == 3)

-- Render each through the real FormatCost, using the exact
-- "FormatCost(...) or '?'" expression AddPinTooltipItemLine uses.
local function renderCost(cost)
    return HA.VendorData:FormatCost(cost) or "?"
end

assert(renderCost(byID[100].cost) ~= "?", "static item must not render '?'")
assert(renderCost(byID[201].cost) ~= "?", "scanned gold item must not render '?'")
assert(renderCost(byID[202].cost) == "50 Trader's Tender",
    "scanned currency item must render like static currency (no C_CurrencyInfo in this env)")
assert(renderCost(byID[203].cost) == "?", "no-price scanned item still renders '?'")

-- Mixed record must render BOTH the gold and the item-token components, not
-- just the gold (this is the exact understatement Argus flagged: "800g"
-- instead of "800g + 5 Item 168327 + 5 Item 168832"). No C_CurrencyInfo/
-- C_Item in this env, so both fall to FormatCost's plain-text fallback paths.
local mixedText = renderCost(byID[300].cost)
assert(mixedText == "800g + 5 Item 168327 + 5 Item 168832",
    "mixed-cost item must render both money and item-token components, got: " .. tostring(mixedText))

assert(renderCost(byID[301].cost) == "3 Item 168327",
    "itemCosts-only item must render (not '?')")

-------------------------------------------------------------------------------
-- 2. Mutant kill test: revert the gather site to the pre-fix behavior
-- (push the raw scanned item straight onto allItems, no normalization) on a
-- scratch copy of the source text -- never mutate the real file. The
-- scanned-gold case must regress to "?"; the static and no-price cases must
-- stay exactly as before (proving the mutant is isolated to the scanned path).
-------------------------------------------------------------------------------

local mutantSource = pinTooltipSource:gsub(
    "                    local cost = HA%.VendorData and HA%.VendorData:NormalizeScannedCost%(item%)\n"
        .. "                    tinsert%(allItems, {itemID = item%.itemID, name = item%.name, cost = cost}%)",
    "                    tinsert(allItems, item)",
    1)
assert(mutantSource ~= pinTooltipSource, "mutant substitution did not match -- update the probe's pattern")

local MutantGatherAllItems = extractGatherFn(mutantSource)
local mutantHA = freshHA()
mutantHA.Addon.db = { global = { scannedVendors = buildScannedVendors() } }
local mutantItems = MutantGatherAllItems(buildVendor(), mutantHA, table.insert)

local mutantByID = {}
for _, item in ipairs(mutantItems) do mutantByID[item.itemID] = item end

-- Regression: scanned item's raw shape has no `.cost` field, so it's nil again.
assert(mutantByID[201].cost == nil, "mutant must reproduce the pre-fix '?' bug for scanned gold items")
assert((mutantHA.VendorData:FormatCost(mutantByID[201].cost) or "?") == "?")

-- Unaffected: static item and no-price item behave the same with or without the fix.
assert(mutantByID[100].cost.gold == 500)
assert(mutantByID[203].cost == nil)

-------------------------------------------------------------------------------
-- 3. Mutant kill test (cycle 2): revert NormalizeScannedCost's itemCosts ->
-- cost.items conversion on a scratch copy of the source text -- never mutate
-- the real file from inside a test. The mixed-cost case must regress to
-- gold-only (the exact silent understatement Argus's REJECT flagged: "800g"
-- instead of "800g + 5 Item 168327 + 5 Item 168832"); the itemCosts-only case
-- must regress all the way to nil (no other cost source to fall back on).
-------------------------------------------------------------------------------

local vendorDataSource = assert(io.open(root .. "/Data/VendorData.lua", "r")):read("*a")

local normalizeFnText = vendorDataSource:match(
    "(function VendorData:NormalizeScannedCost%(scannedItem%).-\nend)")
assert(normalizeFnText ~= nil, "could not extract NormalizeScannedCost function text from VendorData.lua")

local mutantNormalizeFnText, mutationCount = normalizeFnText:gsub(
    "\n    %-%- Convert item%-based currency costs.-\n        hasCost = true\n    end\n",
    "\n", 1)
assert(mutationCount == 1,
    "mutant substitution did not match NormalizeScannedCost's itemCosts block -- update the probe's pattern")
assert(mutantNormalizeFnText ~= normalizeFnText, "mutant text identical to original -- no-op")
-- The mutant must still be valid Lua (a genuine behavioral mutant, not a
-- syntax break that would fail for the wrong reason).
assert(mutantNormalizeFnText:find("scannedItem%.itemCosts") == nil,
    "mutant text must no longer reference scannedItem.itemCosts")

local function loadStandaloneNormalize(fnText)
    local chunk = "local VendorData = {}\n" .. fnText .. "\nreturn VendorData.NormalizeScannedCost"
    return assert(loadstring(chunk, "NormalizeScannedCost-extract"))()
end

local realNormalize = loadStandaloneNormalize(normalizeFnText)
local mutantNormalize = loadStandaloneNormalize(mutantNormalizeFnText)

local mixedRecord = {
    price = 8000000,
    itemCosts = {
        { itemID = 168327, amount = 5, name = "Trader's Tender" },
        { itemID = 168832, amount = 5, name = "Radiant Fragment" },
    },
}

local realCost = realNormalize(nil, mixedRecord)
assert(realCost.gold == 8000000)
assert(realCost.items ~= nil and #realCost.items == 2,
    "sanity: real NormalizeScannedCost must still convert itemCosts")

local mutantCost = mutantNormalize(nil, mixedRecord)
assert(mutantCost.gold == 8000000, "mutation must not touch the gold conversion")
assert(mutantCost.items == nil,
    "mutant (itemCosts branch reverted) must drop item-token costs -- silent understatement reproduced")

-- itemCosts-only record: the real function must still normalize it; the
-- mutant has no other cost source to fall back on, so it must fabricate
-- nothing and return nil (never a fake zero-cost).
local itemOnlyRecord = { itemCosts = { { itemID = 168327, amount = 3, name = "Trader's Tender" } } }
assert(realNormalize(nil, itemOnlyRecord) ~= nil, "sanity: real must normalize an itemCosts-only record")
assert(mutantNormalize(nil, itemOnlyRecord) == nil, "mutant must fabricate no cost for an itemCosts-only record")

print("hs074b_scanned_cost_probe: ok")
