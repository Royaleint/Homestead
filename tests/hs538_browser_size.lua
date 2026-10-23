-- luacheck: globals assert io print pairs
-- Run from the repo root:  lua tests/hs538_browser_size.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Decor Browser stays small: every UI/Browser file the TOC loads, counted
-- without carriage returns, must fit its own ceiling, and together they must fit
-- the cap. A file that grows past its ceiling fails here before it eats the room
-- the next change planned to use. Every TOC'd file needs a ceiling and every
-- ceiling needs a file.
-------------------------------------------------------------------------------

local CAP = 180224

local CEIL = {
    ["Visuals.xml"] = 391,
    ["Style.lua"] = 5900,
    ["Visuals.lua"] = 3482,
    ["Adapter.lua"] = 20000,
    ["Facts.lua"] = 6026,
    ["CanGet.lua"] = 16300,
    ["Widgets.lua"] = 24300,
    ["Window.lua"] = 20900,
    ["Browser.lua"] = 15700,
    ["Summary.lua"] = 10100,
    ["Catalog.lua"] = 15700,
    ["Sources.lua"] = 27400,
    ["Item.lua"] = 13700,
}

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local total, count, seen = 0, 0, {}
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry, name = line:match("^%s*(UI\\Browser\\([%w_\\]+%.[lx][um][al]))%s*$")
    assert(entry or not line:find("UI\\Browser\\", 1, true), "an unreadable TOC line: " .. line)
    if entry then
        local bytes = #readFile((entry:gsub("\\", "/"))):gsub("\r", "")
        local ceil = CEIL[name]
        assert(ceil, name .. " is in the TOC but has no ceiling")
        assert(bytes <= ceil, name .. " is " .. bytes .. " bytes, over its ceiling of " .. ceil)
        seen[name] = bytes
        total = total + bytes
        count = count + 1
    end
end

for name in pairs(CEIL) do
    assert(seen[name], name .. " has a ceiling but is not in the TOC")
end
assert(count >= 8, "the TOC lists too few UI/Browser files")
assert(total <= CAP, "UI/Browser is " .. total .. " bytes, over the cap of " .. CAP)
print("hs538_browser_size: ok (" .. total .. " of " .. CAP .. " bytes in " .. count .. " files)")
