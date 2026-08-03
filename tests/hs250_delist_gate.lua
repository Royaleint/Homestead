-- luacheck: globals assert loadfile print io loadstring

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-250: a known vendor selling only non-decor housing must export its items,
-- not a delist row.
--
-- HS-249 deliberately keeps decorCount / hasDecor / lastScanHadDecor meaning
-- decor only, because decorCount is a wire format archived scans already carry.
-- The consequence is that a vendor selling nothing but room plans or dyes has
-- lastScanHadDecor == false while having scanned perfectly well and captured
-- items. IsDelistCandidate read that flag as "this vendor had nothing", emitted
-- a D row, and suppressed every I row — so freshly captured stock never reached
-- the pipeline, and the pipeline was told to consider retiring a vendor that
-- had just proved it has inventory.
--
-- ExportImport.lua runs WoW-API-heavy work and IsDelistCandidate is file-local,
-- so this extracts and executes the real function body (the hs202 pattern)
-- rather than asserting on source text alone.
-------------------------------------------------------------------------------

local exportSource = assert(io.open(root .. "/Modules/ExportImport.lua", "r")):read("*a")

local functionText = exportSource:match(
    '(local function IsDelistCandidate%(vendor, npcID%).-\nend)')
assert(functionText ~= nil,
    "could not extract IsDelistCandidate function text from ExportImport.lua")

local knownNpcIDs = { [100] = true, [101] = true, [102] = true, [103] = true }
local MockHA = {
    VendorData = {
        HasVendor = function(_, npcID) return knownNpcIDs[npcID] == true end,
    },
}

local chunk = "local _, HA = ...\n" .. functionText .. "\nreturn IsDelistCandidate"
local IsDelistCandidate = assert(loadstring(chunk, "IsDelistCandidate-extract"))("Homestead", MockHA)

local function MakeItems(count)
    local items = {}
    for i = 1, count do items[i] = { itemID = 4000 + i } end
    return items
end

-- 1. THE BUG. A known vendor selling only room plans: eight housing items
--    captured, none of them decor. Must NOT delist.
assert(IsDelistCandidate({
    npcID = 100,
    items = MakeItems(8),
    itemCount = 8,
    decorCount = 0,
    hasDecor = false,
    lastScanHadDecor = false,   -- correct, and not the question being asked
    housingCount = 8,
    hasHousing = true,
    lastScanHadHousing = true,
}, 100) == false,
    "a known vendor selling only non-decor housing must not be a delist candidate")

-- 2. The behaviour being protected must survive. A known vendor that genuinely
--    scanned empty still delists.
assert(IsDelistCandidate({
    npcID = 101,
    items = {},
    itemCount = 0,
    decorCount = 0,
    hasDecor = false,
    lastScanHadDecor = false,
    housingCount = 0,
    hasHousing = false,
    lastScanHadHousing = false,
}, 101) == true,
    "a known vendor that scanned zero housing items must still delist")

-- 3. Legacy record: saved before lastScanHadHousing existed. The decor flag IS
--    the housing answer on those, because decor was the only subclass the old
--    capture gate could see. A legacy vendor that had decor must not delist...
assert(IsDelistCandidate({
    npcID = 102,
    items = MakeItems(5),
    itemCount = 5,
    decorCount = 5,
    hasDecor = true,
    lastScanHadDecor = true,
    -- housingCount / hasHousing / lastScanHadHousing absent — the legacy shape.
}, 102) == false,
    "a legacy record that had decor must not delist via the fallback")

-- ...and a legacy vendor that scanned empty must still delist.
assert(IsDelistCandidate({
    npcID = 103,
    items = {},
    itemCount = 0,
    decorCount = 0,
    hasDecor = false,
    lastScanHadDecor = false,
}, 103) == true,
    "a legacy record that scanned empty must still delist via the fallback")

-- 4. Unknown vendors are never delist candidates regardless of contents. This
--    is why the bug hid: "Fen" Rucket, the vendor that prompted HS-249, is
--    unknown, so it exits here before reaching the flag test and looked fine
--    while already-tracked vendors were silently losing their items.
assert(IsDelistCandidate({
    npcID = 999,
    items = {},
    itemCount = 12,
    lastScanHadDecor = false,
    lastScanHadHousing = false,
}, 999) == false,
    "an unknown vendor is never a delist candidate")

-- 5. The second condition is untouched: stock present but nothing captured is
--    still a genuine review signal.
assert(IsDelistCandidate({
    npcID = 100,
    items = {},
    itemCount = 20,
    lastScanHadDecor = true,
    lastScanHadHousing = true,
}, 100) == true,
    "a known vendor with stock but zero captured items must still delist")

print("hs250_delist_gate: housing-only vendors export instead of delisting ok")
