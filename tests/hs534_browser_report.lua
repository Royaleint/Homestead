-- luacheck: globals assert loadfile print io

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The item page's data-error report. The text is built by a pure function from
-- the gathered fields; it must carry every identifier a data fix needs: the
-- item and record IDs, each vendor's npcID, zone and coordinates, the client
-- build and the addon version.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local HA = { Constants = { TEXTURE_ROOT = "Textures/" } }
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.lua)%s*$")
    if entry then assert(loadfile(root .. "/" .. entry:gsub("\\", "/")))("Homestead", HA) end
end

local item = HA.DecorBrowser.Data
assert(item and type(item.ReportText) == "function", "the data adapter has no report builder")

local function has(text, needle)
    assert(text:find(needle, 1, true), "the report lacks: " .. needle .. "\n" .. text)
end

local text = item.ReportText({
    itemID = 245321, name = "Carved Bench", recordID = 1187,
    build = "12.0.5", buildNumber = "66102", version = "2.14.1",
    vendors = {
        { npcID = 255203, name = "Shop Keeper", zone = "Silvermoon City", mapID = 2393, x = 0.4521, y = 0.6034 },
        { npcID = 219318, name = "Far Trader", zone = "Dornogal" },
    },
})
has(text, "Item: Carved Bench (245321)")
has(text, "Record ID: 1187")
has(text, "Vendor 255203: Shop Keeper, Silvermoon City, map 2393 at 45.2, 60.3")
has(text, "Vendor 219318: Far Trader, Dornogal, no location")
has(text, "Client: 12.0.5 (66102)")
has(text, "Homestead: 2.14.1")

-- The page that gathers the report is the item detail the Catalog hosts: its four-call contract is
-- intact, with nothing else on it, and its Report hands the adapter's builder to the output window.
local detail = HA.DecorBrowser.ItemDetail
for _, name in ipairs({ "Build", "Show", "Clear", "SetCombat" }) do
    assert(type(detail[name]) == "function", "ItemDetail." .. name .. " is missing")
end
local fields = 0
for _ in pairs(detail) do fields = fields + 1 end
assert(fields == 4, "ItemDetail carries more than its four calls")
assert(readFile("UI/Browser/Item.lua"):find("D.ReportText(", 1, true), "the item page no longer reaches the report builder")

-- Missing pieces still produce a complete report, never an error.
text = item.ReportText({ itemID = 7, vendors = {} })
has(text, "Item: ? (7)")
has(text, "Record ID: none")
assert(not text:find("Vendor", 1, true), "a report with no vendors lists one")
has(text, "Client: ? (?)")
has(text, "Homestead: ?")

print("hs534_browser_report: ok")
