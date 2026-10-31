-- luacheck: globals assert io print loadstring ipairs

-- Endeavor vendors show "Endeavor" in the side-panel tooltip instead of an
-- expansion name, and every endeavor data row carries the Midnight expansion.
-- UI/MapSidePanel.lua cannot be loaded whole, so the helper is extracted.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local function read(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local source = read(root .. "/UI/MapSidePanel.lua")
local helper = source:match("(local function VendorExpansionText%(vendor%).-\nend)")
assert(helper, "could not extract VendorExpansionText")

local L = { ["Endeavor"] = "Endeavor-label" }
local chunk = assert(loadstring("local L = ...\n" .. helper .. "\nreturn VendorExpansionText"))
local VendorExpansionText = chunk(L)

assert(VendorExpansionText({ endeavor = true, expansion = "Midnight" }) == "Endeavor-label",
    "an endeavor vendor must show the Endeavor label, not its expansion")
assert(VendorExpansionText({ expansion = "Midnight" }) == "Midnight",
    "a regular vendor must keep its expansion")
assert(VendorExpansionText({ name = "x" }) == nil,
    "a vendor with no expansion shows no line")

-- The tooltip must route through the helper.
assert(source:find("VendorExpansionText(self.vendor)", 1, true),
    "the side-panel tooltip must call VendorExpansionText")
assert(not source:find("AddLine(self.vendor.expansion", 1, true),
    "the tooltip must not print the raw expansion")

-- Data: every endeavor vendor row is Midnight.
local data = read(root .. "/Data/EndeavorsData.lua")
local rows = 0
for block in data:gmatch("\n    %[%d+%] = {(.-)\n    },") do
    if block:find("endeavor = true", 1, true) then
        rows = rows + 1
        assert(block:find('expansion = "Midnight"', 1, true), "endeavor vendor row not Midnight")
    end
end
assert(rows == 12, "expected 12 endeavor vendor rows, found " .. rows)

-- Locale: the label key exists in every locale file.
for _, loc in ipairs({ "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
    assert(read(root .. "/Locale/" .. loc .. ".lua"):find('L["Endeavor"] = ', 1, true),
        loc .. " is missing the Endeavor key")
end

print("hs562 endeavor vendor label: ok")
