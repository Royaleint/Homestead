-- luacheck: globals assert loadfile print io loadstring setmetatable C_HousingCatalog

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Tooltip decor-check cache-only contract (HS-202)
--
-- Overlay/Tooltips.lua has no public module export and runs WoW-API-heavy
-- initialization at file scope (CreateFrame/RegisterEvent/TooltipDataProcessor
-- hooks, C_Timer.After(0, Initialize) at the bottom of the file), so a full
-- functional load isn't practical here the way SourceManager/CatalogStore's
-- clean module boundaries were for the HS-180/HS-200 tests. Instead, this
-- pins the exact IsDecorItem function body: it must delegate to
-- CatalogStore:IsDecorItem (cache-first as of HS-180 — ci record, static
-- DecorMapping index, then a session-only warm-gated negative cache) and
-- must NOT contain a raw C_HousingCatalog probe, which used to fire
-- uncached on every single item-tooltip hover in the game.
-------------------------------------------------------------------------------

local tooltipSource = assert(io.open(root .. "/Overlay/Tooltips.lua", "r")):read("*a")

-- Isolate just the IsDecorItem function body (from its declaration to the
-- first zero-indent "end", which is that function's own closing end — every
-- nested end inside the body is indented and won't match "\nend").
local functionBody = tooltipSource:match(
    'local function IsDecorItem%(itemLink%)(.-)\nend')
assert(functionBody ~= nil, "could not locate IsDecorItem function body in Tooltips.lua")

assert(functionBody:find('HA%.CatalogStore:IsDecorItem%(itemLink%)', 1) ~= nil)
assert(functionBody:find('C_HousingCatalog', 1) == nil)

-------------------------------------------------------------------------------
-- Behavioral check: extract and execute the real function body (stub-to-
-- error pattern from the hs200 test), rather than trust the source-text
-- check alone. C_HousingCatalog is a global that errors on any access at
-- all, so even an indirect/renamed reference to it would trip this.
-------------------------------------------------------------------------------

C_HousingCatalog = setmetatable({}, {
    __index = function()
        error("tooltip IsDecorItem must not touch C_HousingCatalog directly")
    end,
})

local functionText = tooltipSource:match(
    '(local function IsDecorItem%(itemLink%).-\nend)')
assert(functionText ~= nil, "could not extract IsDecorItem function text from Tooltips.lua")

local chunk = "local _, HA = ...\n" .. functionText .. "\nreturn IsDecorItem"
local extractedIsDecorItem = assert(loadstring(chunk, "IsDecorItem-extract"))

local decorCheckCalls = 0
local MockHA = {
    CatalogStore = {
        IsDecorItem = function(_, itemLink)
            decorCheckCalls = decorCheckCalls + 1
            return itemLink == "item:12345"
        end,
    },
}

local isDecorItemFn = extractedIsDecorItem("Homestead", MockHA)
assert(isDecorItemFn("item:12345") == true)
assert(isDecorItemFn("item:99999") == false)
assert(isDecorItemFn(nil) == false)
assert(decorCheckCalls == 2)

print("hs202_tooltip_probe: ok")
