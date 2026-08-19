-- luacheck: globals assert loadfile loadstring print io table ipairs

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-074B (Gate 2 feedback, Rawb): the HS-074/HS-074B vendor-pin tooltip
-- enrichment (source icons, cost column, vendor-only count) needs a
-- default-ON off switch -- "Vendor pin item details" -- and the source
-- glyphs were too large (24px -> 16px).
--
-- This probe extracts and executes the REAL functions from
-- UI/VendorPinTooltips.lua (IsVendorPinItemDetailsEnabled,
-- AddPinTooltipItemLine, and the SOURCE_TOOLTIP_ICONS table that feeds it)
-- rather than reimplementing the logic, and separately confirms the two
-- gather-site call sites are actually wired to the toggle via source-text
-- checks -- mirroring the pattern already established by
-- hs074b_scanned_cost_probe.lua.
-------------------------------------------------------------------------------

local pinTooltipSource = assert(io.open(root .. "/UI/VendorPinTooltips.lua", "r")):read("*a")

-------------------------------------------------------------------------------
-- 1. Icon size: zero remaining :24:24 anywhere in the file (the spec's own
-- verification ask), and the SOURCE_TOOLTIP_ICONS block specifically must be
-- all :16:16.
-------------------------------------------------------------------------------

assert(pinTooltipSource:find(":24:24", 1, true) == nil,
    "no atlas markup in VendorPinTooltips.lua may remain at :24:24 -- Rawb's Gate 2 spec is 16px")

local iconsBlockText = pinTooltipSource:match("local SOURCE_TOOLTIP_ICONS = {(.-)\n}")
assert(iconsBlockText ~= nil, "could not locate SOURCE_TOOLTIP_ICONS table text")
local sixteenCount = select(2, iconsBlockText:gsub(":16:16", ""))
assert(sixteenCount == 4, "expected exactly 4 :16:16 atlas markups in SOURCE_TOOLTIP_ICONS, found " .. sixteenCount)

-------------------------------------------------------------------------------
-- 2. Wiring checks: both consumption sites must read the toggle variable,
-- not a hardcoded true. Source-text presence, not behavioral -- proves the
-- fix is threaded through the real gather function without needing to
-- execute all of ShowVendorTooltip's heavy dependencies (GameTooltip frame,
-- BadgeCalculation, VendorMapPins stats, etc.).
-------------------------------------------------------------------------------

assert(pinTooltipSource:find("isVendorContext = itemDetailsEnabled,", 1, true) ~= nil,
    "the per-item AddPinTooltipItemLine call must gate isVendorContext on the toggle")
assert(pinTooltipSource:find("if itemDetailsEnabled and stats.vendorOnly and stats.vendorOnly > 0 then", 1, true) ~= nil,
    "the Vendor-only summary line must be gated on the toggle")
assert(pinTooltipSource:find("local itemDetailsEnabled = IsVendorPinItemDetailsEnabled%(%)") ~= nil,
    "ShowVendorTooltip must read the gate fresh per tooltip build (not cached at load)")

-------------------------------------------------------------------------------
-- 3. Behavioral check: extract and execute the real IsVendorPinItemDetailsEnabled.
-------------------------------------------------------------------------------

local function extractGateFn(sourceText)
    local fnText = sourceText:match(
        "(local function IsVendorPinItemDetailsEnabled%(%).-\nend)")
    assert(fnText ~= nil, "could not extract IsVendorPinItemDetailsEnabled function text")
    local chunk = "local _, HA = ...\n" .. fnText .. "\nreturn IsVendorPinItemDetailsEnabled"
    return assert(loadstring(chunk, "IsVendorPinItemDetailsEnabled-extract"))
end

local gateLoader = extractGateFn(pinTooltipSource)

-- Case: key explicitly true.
local haOn = { Addon = { db = { profile = { vendorTracer = { showVendorPinItemDetails = true } } } } }
assert(gateLoader(nil, haOn)() == true, "explicit true must read as enabled")

-- Case: key explicitly false.
local haOff = { Addon = { db = { profile = { vendorTracer = { showVendorPinItemDetails = false } } } } }
assert(gateLoader(nil, haOff)() == false, "explicit false must read as disabled")

-- Case: no vendorTracer section at all (addon not yet loaded / no db) --
-- exercises the function's own explicit fallback branch.
local haNoDB = {}
assert(gateLoader(nil, haNoDB)() == true, "missing Addon/db must default to enabled")

-- Case: existing profile, key genuinely absent, backfilled by the REAL
-- Foundry.DB mechanism -- not a hand-modeled stand-in (a probe that applies
-- the transformation itself, then asserts the result, proves its own
-- if-statement, not Foundry's contract). Extract applyDefaults verbatim from
-- Libs/Foundry-1.0/Modules/DB.lua -- it's a pure table-recursion helper with
-- no WoW stubs or Foundry bootstrap needed -- and load the real
-- Constants.Defaults from Core/constants.lua, then run them together
-- against a stored profile shaped like a genuine pre-HS-074B install: the
-- vendorTracer section already exists, with its own customised settings,
-- but never had this key.
local dbSource = assert(io.open(root .. "/Libs/Foundry-1.0/Modules/DB.lua", "r")):read("*a")
local applyDefaultsFnText = dbSource:match(
    "(local function applyDefaults%(stored, defaults, onMismatch, path%).-\nend)")
assert(applyDefaultsFnText ~= nil, "could not extract applyDefaults from DB.lua")
local applyDefaults = assert(loadstring(
    applyDefaultsFnText .. "\nreturn applyDefaults", "applyDefaults-extract"))()

local constantsHA = { Constants = {} }
assert(loadfile(root .. "/Core/constants.lua"))("Homestead", constantsHA)
local profileDefaults = constantsHA.Constants.Defaults.profile

local existingStoredProfile = {
    vendorTracer = {
        showVendorDetails = false, -- customised sibling, must survive untouched
        navigateModifier = "ctrl", -- customised sibling, must survive untouched
        -- showVendorPinItemDetails intentionally absent: pre-HS-074B profile
    },
}
applyDefaults(existingStoredProfile, profileDefaults, nil, "profile.")

assert(existingStoredProfile.vendorTracer.showVendorPinItemDetails == true,
    "the real applyDefaults must backfill the new key to the registered default")
assert(existingStoredProfile.vendorTracer.showVendorDetails == false,
    "backfill must not touch a customised sibling key")
assert(existingStoredProfile.vendorTracer.navigateModifier == "ctrl",
    "backfill must not touch a customised sibling key")

local haExisting = { Addon = { db = { profile = existingStoredProfile } } }
assert(gateLoader(nil, haExisting)() == true,
    "an existing profile, once the real applyDefaults backfills the registered default, must read enabled")

-- applyDefaults is nil-keyed (DB.lua: "A stored value of ANY type,
-- including false, is left untouched") -- an explicit false must survive
-- the same backfill pass unchanged, not get overwritten by the true default.
local explicitFalseProfile = { vendorTracer = { showVendorPinItemDetails = false } }
applyDefaults(explicitFalseProfile, profileDefaults, nil, "profile.")
assert(explicitFalseProfile.vendorTracer.showVendorPinItemDetails == false,
    "an explicit false must survive applyDefaults (nil-keyed backfill only)")

-------------------------------------------------------------------------------
-- 4. Behavioral check: extract and execute the real AddPinTooltipItemLine
-- (plus its SOURCE_TOOLTIP_ICONS/BuildItemSourceIconText upvalues, extracted
-- together since they're closure-linked) against a mock tooltip, proving
-- OFF renders a plain AddLine (no icons, no double-line) and ON renders
-- AddDoubleLine with a 16:16 icon glyph.
-------------------------------------------------------------------------------

local function extractItemLineFn(sourceText)
    -- Anchored on the NEXT function's code line (not its comment prose
    -- above it) -- a comment-anchored pattern breaks on a plain comment
    -- edit or ticket-ID rename, which is exactly what just happened here.
    local blockText = sourceText:match(
        "(local SOURCE_TOOLTIP_ICONS = {.-)\nlocal function IsVendorPinItemDetailsEnabled%(%)")
    assert(blockText ~= nil, "could not extract the SOURCE_TOOLTIP_ICONS/AddPinTooltipItemLine block")
    -- item.name is always supplied by every fixture below, so the
    -- RequestItemDataForTooltip/C_Item.GetItemInfo fallback branch (both
    -- upvalues from outside this extracted region) is never reached --
    -- no stub needed for either.
    local chunk = "local _, HA = ...\n"
        .. "local ipairs = ipairs\n"
        .. blockText
        .. "\nreturn AddPinTooltipItemLine"
    return assert(loadstring(chunk, "AddPinTooltipItemLine-extract"))
end

local itemLineLoader = extractItemLineFn(pinTooltipSource)

local function mockTooltip()
    return {
        lines = {},
        AddLine = function(self, text, r, g, b)
            table.insert(self.lines, { kind = "AddLine", text = text })
        end,
        AddDoubleLine = function(self, left, right, lr, lg, lb, rr, rg, rb)
            table.insert(self.lines, { kind = "AddDoubleLine", left = left, right = right })
        end,
    }
end

-- Mock SourceManager: one "quest" source, so BuildItemSourceIconText has a
-- real glyph to append -- lets the ON case prove the 16:16 size reaches the
-- actual rendered string, not just that SOURCE_TOOLTIP_ICONS holds 16:16 in
-- isolation.
local function buildHA()
    return {
        SourceManager = {
            GetItemPresentation = function(_, itemID, options)
                return { availabilityState = nil, allSources = { { type = "quest" } } }
            end,
            NormalizeSourceType = function(_, t) return t end,
        },
    }
end

local AddPinTooltipItemLine = itemLineLoader(nil, buildHA())

-- OFF: pre-HS-074 plain rendering. No icons, no cost column, no double-line.
local tooltipOff = mockTooltip()
AddPinTooltipItemLine(tooltipOff, { itemID = 500, name = "Plain Item" },
    { context = "vendorMapPin", npcID = 1, isVendorContext = false })
assert(#tooltipOff.lines == 1)
assert(tooltipOff.lines[1].kind == "AddLine", "OFF must render a plain AddLine, not AddDoubleLine")
assert(tooltipOff.lines[1].text == "  Plain Item", "OFF must not append source icons to the line text")

-- ON: current HS-074/HS-074B rendering, icons now at 16:16.
local tooltipOn = mockTooltip()
AddPinTooltipItemLine(tooltipOn, { itemID = 501, name = "Enriched Item" },
    { context = "vendorMapPin", npcID = 1, isVendorContext = true })
assert(#tooltipOn.lines == 1)
assert(tooltipOn.lines[1].kind == "AddDoubleLine", "ON must render AddDoubleLine")
assert(tooltipOn.lines[1].left:find("Enriched Item", 1, true) ~= nil)
assert(tooltipOn.lines[1].left:find(":16:16", 1, true) ~= nil, "ON must render the 16:16 source icon")
assert(tooltipOn.lines[1].left:find(":24:24", 1, true) == nil, "ON must never render the old 24:24 icon")

print("hs074b_pin_details_toggle_probe: cases ok, running mutant kills...")

-------------------------------------------------------------------------------
-- 5. Mutant kill tests (in-memory scratch-text mutation, never the real
-- file -- safe to run in CI). Each mutant targets exactly one mechanism.
-------------------------------------------------------------------------------

-- 5a. Revert the per-item wiring: isVendorContext hardcoded true again.
local mutantA, countA = pinTooltipSource:gsub(
    "isVendorContext = itemDetailsEnabled,", "isVendorContext = true,", 1)
assert(countA == 1, "mutant 5a substitution did not match")
assert(mutantA:find("isVendorContext = itemDetailsEnabled,", 1, true) == nil,
    "mutant 5a must no longer wire isVendorContext to the toggle")

-- 5b. Revert the vendor-only summary gate.
local mutantB, countB = pinTooltipSource:gsub(
    "if itemDetailsEnabled and stats.vendorOnly and stats.vendorOnly > 0 then",
    "if stats.vendorOnly and stats.vendorOnly > 0 then", 1)
assert(countB == 1, "mutant 5b substitution did not match")
assert(mutantB:find("if itemDetailsEnabled and stats.vendorOnly and stats.vendorOnly > 0 then", 1, true) == nil,
    "mutant 5b must no longer gate the vendor-only line on the toggle")

-- 5c. Break IsVendorPinItemDetailsEnabled so it always reports enabled,
-- regardless of the stored setting -- the OFF case must then fail to
-- suppress the enrichment. Re-extract and re-run case 3's "explicit false"
-- assertion against the mutant; it must now read true (wrong).
local mutantGateSource, countC = pinTooltipSource:gsub(
    "    if not vendorTracer then return true end\n    return vendorTracer%.showVendorPinItemDetails\nend",
    "    if not vendorTracer then return true end\n    return true\nend", 1)
assert(countC == 1, "mutant 5c substitution did not match")
assert(mutantGateSource ~= pinTooltipSource, "mutant 5c text identical to original -- no-op")

local mutantGateLoader = extractGateFn(mutantGateSource)
local mutantResult = mutantGateLoader(nil, haOff)()
assert(mutantResult == true,
    "mutant 5c (gate always returns true) must incorrectly read the OFF profile as enabled -- proves the real gate's own return value is load-bearing")
-- Sanity: the REAL (unmutated) gate must still correctly read false for the same input.
assert(gateLoader(nil, haOff)() == false, "sanity: real gate must still read OFF correctly after mutant 5c was built")

-- 5d. Break the REAL applyDefaults' scalar backfill (mutate its extracted
-- source text, never the live DB.lua file) so a nil key is never filled.
-- Feed the mutant the same "existing profile, key absent" fixture the real
-- backfill case above used; it must now stay nil, and the gate must not
-- read it as enabled -- proving those two earlier assertions actually
-- depend on the real backfill running, not on the fixture happening to
-- already be true.
local mutantApplyDefaultsText, countD = applyDefaultsFnText:gsub(
    "stored%[k%] = dv", "local _mutated_noop = dv", 1)
assert(countD == 1, "mutant 5d substitution did not match applyDefaults' scalar-backfill line")
assert(mutantApplyDefaultsText ~= applyDefaultsFnText, "mutant 5d text identical to original -- no-op")

local mutantApplyDefaults = assert(loadstring(
    mutantApplyDefaultsText .. "\nreturn applyDefaults", "applyDefaults-mutant"))()

local mutantStoredProfile = {
    vendorTracer = { showVendorDetails = false, navigateModifier = "ctrl" },
}
mutantApplyDefaults(mutantStoredProfile, profileDefaults, nil, "profile.")
assert(mutantStoredProfile.vendorTracer.showVendorPinItemDetails == nil,
    "mutant 5d (backfill disabled) must leave the key nil -- proves the real applyDefaults call is load-bearing")

local mutantHAExisting = { Addon = { db = { profile = mutantStoredProfile } } }
assert(gateLoader(nil, mutantHAExisting)() ~= true,
    "mutant 5d: without the real backfill, the gate must NOT read the existing profile as enabled")

print("hs074b_pin_details_toggle_probe: ok")
