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
-- Gate 2 feedback #2 (Rawb, 2026-08-18): a COSTLESS static/offer row (e.g.
-- Ironus Coldsteel, npcID 209220, item 248652, VendorOffers.lua row
-- `price = 0, currencies = {}`) still rendered "?" forever, even after the
-- player scanned the vendor for real, because the static loop added the
-- item first with cost = nil and marked it seen, permanently shadowing the
-- scanned loop's real price below it. The gather now builds a scanned
-- itemID -> cost map ONCE before the static loop and backfills a nil
-- static cost from it; a static row that already has a cost keeps it
-- (curated static cost stays authoritative).
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

    local chunk = "local function GatherAllItems(vendor, HA, tinsert, itemDetailsEnabled)\n"
        .. body .. "\n    end\n"
        .. "    return allItems\nend\nreturn GatherAllItems"
    return assert(loadstring(chunk, "GatherAllItems-extract"))()
end

local pinTooltipSource = assert(io.open(root .. "/UI/VendorPinTooltips.lua", "r")):read("*a")

-- Confirm the fix is wired at the gather site, not smuggled into the render
-- call (AddPinTooltipItemLine's FormatCost call must stay untouched).
assert(pinTooltipSource:find("HA%.VendorData:NormalizeScannedCost%(item%)", 1) ~= nil,
    "scanned-item gather must call VendorData:NormalizeScannedCost")

-- Confirm the backfill is wired: a nil static cost must read from the
-- scanned-cost map built ahead of the static loop.
assert(pinTooltipSource:find("cost = scannedCostByItemID%[itemID%]", 1) ~= nil,
    "static gather must backfill a nil cost from scannedCostByItemID")

-- Argus Minor 2: the scanned-cost map build must be gated on itemDetailsEnabled
-- (AddPinTooltipItemLine never reads item.cost when the vendor-pin item
-- details toggle is off, so normalizing scanned costs in that state is waste).
assert(pinTooltipSource:find("if scannedItems and itemDetailsEnabled then", 1) ~= nil,
    "scanned-cost map build must be gated on itemDetailsEnabled")

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
            -- Gate 2 feedback #2 backfill cases:
            { itemID = 400 }, -- costless static row (Ironus Coldsteel shape) + scanned price exists
            { itemID = 401, cost = { gold = 999 } }, -- static row WITH a cost + scanned row has a DIFFERENT price
            { itemID = 402 }, -- costless static row, no scanned record at all
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
                -- Gate 2 feedback #2: real scanned price for a costless static row (400).
                { itemID = 400, name = "Backfill Target Item", price = 54321 },
                -- Gate 2 feedback #2: DIFFERENT scanned price for a static row that
                -- already has a curated cost (401) -- static must win, not this.
                { itemID = 401, name = "Static-Wins Item", price = 111111 },
                -- No scanned entry for 402 -- case 3 (no scanned data at all).
                -- Argus Minor 1: VendorScanner emits one record per merchant slot
                -- with no dedup, so the SAME itemID can appear more than once in
                -- a real scannedVendors.items array. First occurrence is a
                -- costless/unfinished scan of that slot; the map must keep the
                -- FIRST NON-NIL cost seen (occurrence B, 7777), not the literal
                -- first occurrence (nil) and not the last occurrence (occurrence
                -- C, 8888 -- "last-wins" would be wrong).
                { itemID = 500, name = "Duplicate Slot A (costless)" },
                { itemID = 500, name = "Duplicate Slot B (has price)", price = 7777 },
                { itemID = 500, name = "Duplicate Slot C (different price)", price = 8888 },
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

local allItems = GatherAllItems(buildVendor(), HA, table.insert, true)
-- 4 static rows (100, 400, 401, 402) + 6 scanned-only rows (201, 202, 203, 300,
-- 301, 500). 400 and 401 also appear in scannedVendors, but itemsSeen dedup
-- keeps them as the static entry (backfilled/kept authoritative below), not a
-- second scanned-loop entry. 500 appears three times in scannedVendors but
-- collapses to one allItems entry (itemsSeen dedup applies within the
-- scanned loop too).
assert(#allItems == 10, "expected 4 static + 6 scanned-only items, got " .. #allItems)

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

-- Gate 2 feedback #2 backfill cases.
-- Case 1: costless static row + a scanned record with a real price -> backfilled.
assert(byID[400].cost ~= nil, "costless static row must backfill from the scanned price")
assert(byID[400].cost.gold == 54321, "backfilled cost must be the scanned vendor's real price")
assert(renderCost(byID[400].cost) ~= "?", "backfilled item must not render '?'")

-- Case 2: static row already has a cost + scanned record has a DIFFERENT
-- price -> curated static cost wins, scanned price is ignored.
assert(byID[401].cost ~= nil)
assert(byID[401].cost.gold == 999, "curated static cost must win over a conflicting scanned price")
assert(renderCost(byID[401].cost) ~= "?")

-- Case 3: costless static row, no scanned record at all -> still "?", never fabricated.
assert(byID[402].cost == nil, "costless static row with no scanned data must not fabricate a cost")
assert(renderCost(byID[402].cost) == "?")

-- Argus Minor 1: duplicate scanned records for the same itemID -- the FIRST
-- non-nil cost must win (occurrence B, 7777), never the literal first
-- occurrence (nil) and never the last occurrence (occurrence C, 8888).
assert(byID[500].cost ~= nil, "duplicate-itemID scanned records must still normalize to a cost")
assert(byID[500].cost.gold == 7777,
    "first NON-NIL cost among duplicate itemIDs must win, got " .. tostring(byID[500].cost.gold))
assert(renderCost(byID[500].cost) ~= "?")

-------------------------------------------------------------------------------
-- 2. Mutant kill test: revert the gather site to the pre-fix behavior
-- (push the raw scanned item straight onto allItems, no normalization) on a
-- scratch copy of the source text -- never mutate the real file. The
-- scanned-gold case must regress to "?"; the static and no-price cases must
-- stay exactly as before (proving the mutant is isolated to the scanned path).
-------------------------------------------------------------------------------

local mutantSource, mutationCount1 = pinTooltipSource:gsub(
    "                    scannedCostByItemID%[item%.itemID%] = HA%.VendorData and HA%.VendorData:NormalizeScannedCost%(item%)",
    "                    scannedCostByItemID[item.itemID] = nil",
    1)
assert(mutationCount1 == 1, "mutant substitution did not match -- update the probe's pattern")
assert(mutantSource ~= pinTooltipSource, "mutant substitution produced identical text -- no-op")

local MutantGatherAllItems = extractGatherFn(mutantSource)
local mutantHA = freshHA()
mutantHA.Addon.db = { global = { scannedVendors = buildScannedVendors() } }
local mutantItems = MutantGatherAllItems(buildVendor(), mutantHA, table.insert, true)

local mutantByID = {}
for _, item in ipairs(mutantItems) do mutantByID[item.itemID] = item end

-- Regression: with the scanned-cost map disabled, scanned costs vanish again.
assert(mutantByID[201].cost == nil, "mutant must reproduce the pre-fix '?' bug for scanned gold items")
assert((mutantHA.VendorData:FormatCost(mutantByID[201].cost) or "?") == "?")

-- Regression: the backfill has nothing to draw from either, so case 1 fails too.
assert(mutantByID[400].cost == nil, "mutant must also break the scanned-price backfill (400)")

-- Unaffected: static items that already carry a cost don't need the map.
assert(mutantByID[100].cost.gold == 500)
assert(mutantByID[401].cost.gold == 999, "static-wins case must be unaffected by disabling the scanned map")
assert(mutantByID[203].cost == nil)
assert(mutantByID[402].cost == nil)

-------------------------------------------------------------------------------
-- 2b. Mutant kill test: revert ONLY the backfill step in the static loop
-- (drop the "if cost == nil then cost = scannedCostByItemID[itemID] end"
-- fallback), leaving the scanned-cost map and the scanned loop untouched.
-- This isolates the exact Gate 2 feedback #2 mechanism: case 1 (backfill)
-- must fail while case 2 (static wins) and case 3 (no scanned data) stay
-- green, because neither of those cases relies on the fallback firing.
-------------------------------------------------------------------------------

local backfillMutantSource, mutationCount2 = pinTooltipSource:gsub(
    "            local cost = HA%.VendorData:GetItemCost%(item%)\n"
        .. "            if cost == nil then\n"
        .. "                cost = scannedCostByItemID%[itemID%]\n"
        .. "            end\n"
        .. "            tinsert%(allItems, {itemID = itemID, cost = cost}%)",
    "            local cost = HA.VendorData:GetItemCost(item)\n"
        .. "            tinsert(allItems, {itemID = itemID, cost = cost})",
    1)
assert(mutationCount2 == 1, "backfill mutant substitution did not match -- update the probe's pattern")
assert(backfillMutantSource ~= pinTooltipSource, "backfill mutant produced identical text -- no-op")

local BackfillMutantGatherAllItems = extractGatherFn(backfillMutantSource)
local backfillMutantHA = freshHA()
backfillMutantHA.Addon.db = { global = { scannedVendors = buildScannedVendors() } }
local backfillMutantItems = BackfillMutantGatherAllItems(buildVendor(), backfillMutantHA, table.insert, true)

local backfillMutantByID = {}
for _, item in ipairs(backfillMutantItems) do backfillMutantByID[item.itemID] = item end

-- Case 1 must fail: no backfill fallback means the costless static row stays nil.
assert(backfillMutantByID[400].cost == nil,
    "backfill mutant must reproduce the pre-fix '?' bug for a costless static row with real scanned data")
assert((backfillMutantHA.VendorData:FormatCost(backfillMutantByID[400].cost) or "?") == "?")

-- Case 2 and 3 must stay green: neither depends on the backfill fallback firing.
assert(backfillMutantByID[401].cost.gold == 999, "static-wins case must be unaffected by the backfill mutant")
assert(backfillMutantByID[402].cost == nil, "no-scanned-data case must be unaffected by the backfill mutant")
assert(backfillMutantByID[100].cost.gold == 500)

-------------------------------------------------------------------------------
-- 2c. Mutant kill test (Argus Minor 1): delete the "== nil" guard in the
-- scanned-cost map build, turning "first non-nil cost wins" into "last write
-- wins" for duplicate itemIDs. Without the itemID-500 fixture above, this
-- mutant is invisible (no fixture has a duplicate itemID to expose it) --
-- that's exactly why it survived the prior probe. With the fixture, the
-- mutant must change 500's cost from 7777 (first non-nil, real behavior) to
-- 8888 (the last duplicate record processed).
-------------------------------------------------------------------------------

local guardMutantSource, mutationCount3 = pinTooltipSource:gsub(
    "if item%.itemID and scannedCostByItemID%[item%.itemID%] == nil then",
    "if item.itemID then",
    1)
assert(mutationCount3 == 1, "guard mutant substitution did not match -- update the probe's pattern")
assert(guardMutantSource ~= pinTooltipSource, "guard mutant produced identical text -- no-op")

local GuardMutantGatherAllItems = extractGatherFn(guardMutantSource)
local guardMutantHA = freshHA()
guardMutantHA.Addon.db = { global = { scannedVendors = buildScannedVendors() } }
local guardMutantItems = GuardMutantGatherAllItems(buildVendor(), guardMutantHA, table.insert, true)

local guardMutantByID = {}
for _, item in ipairs(guardMutantItems) do guardMutantByID[item.itemID] = item end

-- Regression: last-wins now picks occurrence C's price instead of B's.
assert(guardMutantByID[500].cost.gold == 8888,
    "guard mutant must regress duplicate-itemID resolution to last-wins (8888), got "
        .. tostring(guardMutantByID[500].cost.gold))
assert(guardMutantByID[500].cost.gold ~= 7777,
    "guard mutant must diverge from the real code's first-non-nil result")

-- Unaffected: every fixture item here has at most one scanned record, so the
-- guard's presence or absence makes no difference to them.
assert(guardMutantByID[400].cost.gold == 54321)
assert(guardMutantByID[401].cost.gold == 999)
assert(guardMutantByID[100].cost.gold == 500)
assert(guardMutantByID[402].cost == nil)

-------------------------------------------------------------------------------
-- 2d. Argus Minor 2: with the vendor-pin item-details toggle off, the
-- scanned-cost map must not be built at all -- AddPinTooltipItemLine never
-- reads item.cost in that state (isVendorContext false), so normalizing
-- every scanned record would be pure waste. Item identity/listing (itemID,
-- name) must still come through unchanged; only cost data goes missing.
-------------------------------------------------------------------------------

local toggleOffHA = freshHA()
toggleOffHA.Addon.db = { global = { scannedVendors = buildScannedVendors() } }
local toggleOffItems = GatherAllItems(buildVendor(), toggleOffHA, table.insert, false)

assert(#toggleOffItems == 10, "item listing must be identical whether or not the toggle is on")

local toggleOffByID = {}
for _, item in ipairs(toggleOffItems) do toggleOffByID[item.itemID] = item end

-- Static rows that already carried a pre-normalized cost are untouched --
-- GetItemCost is a cheap unpack, not gated, so this cost was never in doubt.
assert(toggleOffByID[100].cost.gold == 500)
assert(toggleOffByID[401].cost.gold == 999)

-- The scanned-cost map was never built, so nothing has a scanned-derived cost:
-- no backfill for 400, and no direct cost for any scanned-only item.
assert(toggleOffByID[400].cost == nil, "toggle off must skip the scanned-price backfill")
assert(toggleOffByID[402].cost == nil)
assert(toggleOffByID[201].cost == nil, "toggle off must skip scanned-cost normalization entirely")
assert(toggleOffByID[500].cost == nil, "toggle off must skip scanned-cost normalization entirely")

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
