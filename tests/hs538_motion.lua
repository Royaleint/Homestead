-- luacheck: globals assert print io
-- Run from the repo root:  lua tests/hs538_motion.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Browser motion: open 0.15 s, close 0.1 s, travel at most 8 px, one glow
-- helper, no loops, and the side tabs' own glow never started. The timings at
-- run time are checked in hs538_window.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local files = {}
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_]+%.[lx][um][al])%s*$")
    if entry then files[#files + 1] = (entry:gsub("\\", "/")) end
end
assert(#files >= 10, "the TOC lists too few UI/Browser files")

local window = readFile("UI/Browser/Window.lua")
local open, close, travel = window:match("OPEN_TIME, CLOSE_TIME, TRAVEL = ([%d%.]+), ([%d%.]+), ([%d%.]+)")
assert(tonumber(open) == 0.15 and tonumber(close) == 0.1 and tonumber(travel) <= 8,
    "the open, close or travel timing changed")
for d in window:gmatch("SetDuration%(([^)]*)%)") do
    assert(d == "0" or d == "OPEN_TIME" or d == "CLOSE_TIME", "an animation has its own duration: " .. d)
end

local groups = 0
for _, path in ipairs(files) do
    local text = readFile(path)
    assert(not text:find("TabGlowAnimation", 1, true), path .. " touches the side tab's glow")
    for arg in text:gmatch("SetLooping%s*%(%s*([^)]-)%s*%)") do
        assert(arg:gsub("[\"']", ""):upper() == "NONE", path .. " loops an animation")
    end
    for value in text:gmatch("looping%s*=%s*[\"']([^\"']*)[\"']") do
        assert(value:upper() == "NONE", path .. " loops an animation")
    end
    local _, n = text:gsub("CreateAnimationGroup", "")
    if path ~= "UI/Browser/Window.lua" then
        assert(n == 0, path .. " builds its own animation; motion lives in Window.lua")
    end
    groups = groups + n
end
assert(groups == 3, "Window.lua must build exactly the open fade, the close fade and the one glow")

print("hs538_motion: ok")
