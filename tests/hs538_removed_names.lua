-- luacheck: globals assert io os package print
-- Run from the repo root:  lua tests/hs538_removed_names.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Names the Decor Browser removed must not come back, in its code or in any test.
-- The router, the pages' own routes and the per-item records replaced them; a
-- test that still drove the old calls would be testing a path no player takes.
-- The test files are scanned too, and this file is the one exception because it
-- has to spell the patterns out.
-------------------------------------------------------------------------------

local BANNED = {
    "B%.ShowTab", "B%.RegisterTab", "B%.SetLocation", "Win%.SetLocation", "Win%.TABS", "SetSelectedTab",
    "NewColumns", "ScaleDisplay", "OwnState", "B%.ItemDetail", "DecorBrowser%.ItemDetail", "SetAlpha%(dim",
    "B%.TabOf",
}

-- The Near You list is gone from the browser. A bare "near" stays legal: Nearness, the
-- vendor's near field and the nearYou data helper are still real.
local BANNED_IN_BROWSER = { 'L%["Near You"%]', '"nearYou"', 'L%["Not yet: next step"%]',
    'L%["Can get now means this character can buy' }

local self = "hs538_removed_names.lua"

local function list(dir)
    local windows = package.config:sub(1, 1) == "\\"
    local path = root .. "/" .. dir
    local pipe = assert(io.popen(windows and ('dir /b "' .. path:gsub("/", "\\") .. '"') or ('ls "' .. path .. '"')))
    local names = {}
    for name in pipe:lines() do
        name = name:gsub("\r", "")
        if name:match("%.lua$") then names[#names + 1] = name end
    end
    pipe:close()
    return names
end

local scanned, hits = 0, {}

local function scan(dir, patterns)
    local names = list(dir)
    assert(#names > 0, "no Lua files found in " .. dir)
    for _, name in ipairs(names) do
        if not (dir == "tests" and name == self) then
            local file = assert(io.open(root .. "/" .. dir .. "/" .. name, "rb"))
            local n = 0
            for line in file:lines() do
                n = n + 1
                for _, pattern in ipairs(patterns) do
                    if line:find(pattern) then hits[#hits + 1] = dir .. "/" .. name .. ":" .. n .. " " .. pattern end
                end
            end
            file:close()
            scanned = scanned + 1
        end
    end
end

scan("UI/Browser", BANNED)
scan("tests", BANNED)
scan("UI/Browser", BANNED_IN_BROWSER)

assert(#hits == 0, "removed names are back:\n  " .. table.concat(hits, "\n  "))
print("hs538_removed_names: ok (" .. scanned .. " files scanned)")
