-- luacheck: globals assert io print
-- Run from the repo root:  lua tests/hs538_browser_size.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Decor Browser stays small: every UI/Browser file the TOC loads, counted
-- without carriage returns, must fit in the byte budget.
-------------------------------------------------------------------------------

local BUDGET = 163840

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local total, count = 0, 0
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_\\]+%.[lx][um][al])%s*$")
    if entry then
        local text = readFile((entry:gsub("\\", "/")))
        local bytes = #text:gsub("\r", "")
        total = total + bytes
        count = count + 1
    end
end

assert(count >= 8, "the TOC lists too few UI/Browser files")
assert(total <= BUDGET, "UI/Browser is " .. total .. " bytes, over the budget of " .. BUDGET)
print("hs538_browser_size: ok (" .. total .. " of " .. BUDGET .. " bytes in " .. count .. " files)")
