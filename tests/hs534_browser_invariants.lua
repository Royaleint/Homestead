-- luacheck: globals assert io print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor browser structure bans. A static scan of every UI/Browser file the TOC
-- loads: the browser reads ownership from the cache only, writes nothing
-- through CatalogStore, touches no Blizzard frame or secure path it does not
-- own, and keeps one ownership read behind the adapter.
-------------------------------------------------------------------------------

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local files = {}
for line in readFile("Homestead.toc"):gmatch("[^\r\n]+") do
    local entry = line:match("^%s*(UI\\Browser\\[%w_\\]+%.[lx][um][al])%s*$")
    if entry then files[#files + 1] = entry:gsub("\\", "/") end
end
assert(#files >= 9, "the TOC lists too few UI/Browser files")

local function stripComments(text, path)
    if path:match("%.xml$") then return (text:gsub("<!%-%-.-%-%->", "")) end
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

local sources = {}
for _, path in ipairs(files) do sources[path] = stripComments(readFile(path), path) end

local function fail(path, what)
    error(path .. ": " .. what, 0)
end

-- Plain substrings that must not appear anywhere.
local bannedPlain = {
    "SetOwned", "SetUnowned", "ProbeByDecorID",
    "GetItemAvailabilityState", "GetItemStatusIcon", "GetItemStatusColor",
    "UISpecialFrames", "hooksecurefunc", "WorldMapFrame", "QuestMapFrame_",
    "SetItemRef", "ItemRefTooltip", "HousingModelPreviewFrame", "UnregisterCallbacks",
    '"HIGH"', "AddOns\\\\Homestead", "AddOns/Homestead",
}

-- Whole words that must not appear (GameTooltipTemplate and GameTooltip_Add*Line are fine).
local bannedWords = { "GameTooltip" }

-- Calls that are allowed only in one form. Each rule checks the argument text of every call.
local callRules = {
    { name = "IsOwnedFresh", what = "IsOwnedFresh without a read-only flag",
      ok = function(args) return args:match(",%s*true%s*$") ~= nil end },
    { name = "GetVendorItemAvailabilityState",
      what = "GetVendorItemAvailabilityState must be the three-argument form ending in true",
      ok = function(args) return args:match("^[^,]+,[^,]+,%s*true%s*$") ~= nil end },
    { name = "GetItemPresentation", what = 'GetItemPresentation must pass context = "browser"',
      ok = function(args) return args:match('context%s*=%s*"browser"') ~= nil end },
}

-- Checks every direct call of rule.name in text, and that no other use of the name exists
-- (an alias or a stored reference would dodge the argument check). Returns the call count.
local function scanCalls(path, text, rule)
    local calls, init = 0, 1
    while true do
        local s, e = text:find("%f[%w_]" .. rule.name .. "%s*%(", init)
        if not s then break end
        local args = text:match("^%b()", e)
        if not args then fail(path, rule.name .. " call is not balanced") end
        calls = calls + 1
        if not rule.ok(args:sub(2, -2)) then fail(path, rule.what) end
        init = e
    end
    local tokens = 0
    for _ in text:gmatch("%f[%w_]" .. rule.name .. "%f[^%w_]") do tokens = tokens + 1 end
    if tokens ~= calls then fail(path, rule.name .. " is used other than as a direct call") end
    return calls
end

-- The one allowed use of the word: creating the browser's own named tooltip.
local function allowOwnTooltip(text)
    return (text:gsub('CreateFrame%("GameTooltip", "HomesteadBrowserTooltip"', ""))
end
assert(allowOwnTooltip('CreateFrame("GameTooltip", nil, UIParent)'):find("%f[%w_]GameTooltip%f[^%w_]"),
    "the tooltip allowance must not cover other tooltips")

local presentationCalls = 0
for _, path in ipairs(files) do
    local text = sources[path]
    for _, needle in ipairs(bannedPlain) do
        if text:find(needle, 1, true) then fail(path, "banned: " .. needle) end
    end
    local wordText = allowOwnTooltip(text)
    for _, word in ipairs(bannedWords) do
        if wordText:find("%f[%w_]" .. word .. "%f[^%w_]") then fail(path, "banned word: " .. word) end
    end

    for _, rule in ipairs(callRules) do
        local calls = scanCalls(path, text, rule)
        -- Presentation reads live in the adapter only.
        if rule.name == "GetItemPresentation" then
            if calls > 0 and not path:match("/Adapter%.lua$") then
                fail(path, "GetItemPresentation outside the adapter")
            end
            presentationCalls = presentationCalls + calls
        end
    end
end
assert(presentationCalls >= 1, "the adapter makes no presentation read; the scan is vacuous")

-- The shop's map card stays display-only: its click switch is off, and the world map is
-- opened nowhere else.
do
    local shop = sources["UI/Browser/Shop.lua"]
    assert(shop, "the shop page is not in the TOC")
    assert(shop:find("local MAP_CARD_CLICK = false", 1, true), "the map card click switch must be off")
    for _, path in ipairs(files) do
        if sources[path]:find("OpenWorldMap", 1, true) then
            assert(path == "UI/Browser/Shop.lua", path .. ": opens the world map outside the map card")
            assert(sources[path]:find("if MAP_CARD_CLICK then", 1, true), "the world map open is not behind the switch")
        end
    end
end

-- Blizzard's achievement journal opens from one place: the shared helper in Widgets.lua, directly
-- after its combat check. The pages that use it go through that helper.
do
    local calls, tokens = 0, 0
    for _, path in ipairs(files) do
        local text = sources[path]
        local n = 0
        for _ in text:gmatch("ShowAchievementFrameForAchievement%s*%(") do n = n + 1 end
        for _ in text:gmatch("%f[%w_]ShowAchievementFrameForAchievement%f[^%w_]") do tokens = tokens + 1 end
        if n > 0 then
            assert(path == "UI/Browser/Widgets.lua", path .. ": opens the achievement journal outside the helper")
            assert(text:find("function W%.OpenAchievement%(%w+%)%s+if InCombatLockdown%(%) then return end%s+"
                .. "ShowAchievementFrameForAchievement%("),
                "the achievement journal opens without a combat check")
        end
        calls = calls + n
    end
    assert(calls == 1, "expected one achievement journal call site, found " .. calls)
    assert(tokens == calls, "ShowAchievementFrameForAchievement is used other than as a direct call")
    for _, path in ipairs({ "UI/Browser/Item.lua", "UI/Browser/Sources.lua" }) do
        assert(sources[path]:find("W.OpenAchievement(", 1, true), path .. " does not use the shared opener")
    end
end

-- Quest hyperlinks show on the browser's own tooltip only: the quest log and map are never opened.
do
    local text = sources["UI/Browser/Sources.lua"]
    assert(text:find('GetQuestLink(d.questID) or ("quest:" .. d.questID)', 1, true),
        "quest rows lack the quest: fallback link")
end

-- The scan must catch what it claims to: run the same rules against known-bad text.
do
    local bad = {
        "CatalogStore:IsOwnedFresh(itemID)",
        "CatalogStore:IsOwnedFresh (itemID)",
        "CatalogStore:IsOwnedFresh(\n    itemID\n)",
        "local f = CatalogStore.IsOwnedFresh; f(CatalogStore, itemID)",
        "SM:GetVendorItemAvailabilityState(itemID, npcID)",
        'SM:GetItemPresentation(itemID, { context = "sidePanel" })',
        "local g = SM.GetItemPresentation",
    }
    for _, snippet in ipairs(bad) do
        local caught = false
        for _, rule in ipairs(callRules) do
            if not pcall(scanCalls, "probe", snippet, rule) then caught = true end
        end
        assert(caught, "the call rules missed: " .. snippet)
    end
    local good = 'SM:GetItemPresentation(itemID, { context = "browser" }) CS:IsOwnedFresh(itemID, true)'
    for _, rule in ipairs(callRules) do
        assert(pcall(scanCalls, "probe", good, rule), "the call rules rejected an allowed call")
    end
end

print("hs534_browser_invariants: ok (" .. #files .. " files)")

