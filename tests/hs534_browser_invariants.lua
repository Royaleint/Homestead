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
assert(#files >= 8, "the TOC lists too few UI/Browser files")

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
    "SetOwned", "SetUnowned", "ProbeByDecorID", "GetItemPresentation",
    "GetItemAvailabilityState", "GetItemStatusIcon", "GetItemStatusColor",
    "UISpecialFrames", "UIPanelWindows", "ShowUIPanel", "hooksecurefunc", "WorldMapFrame", "QuestMapFrame_",
    "SetItemRef", "ItemRefTooltip", "HousingModelPreviewFrame", "UnregisterCallbacks",
    '"HIGH"', "AddOns\\\\Homestead", "AddOns/Homestead",
    "CreateCatalogSearcher", "C_Map.OpenWorldMap", "TabGlowAnimation",
    "ShowAchievementFrameForAchievement", "C_Item.GetItemQualityColor",
    "RightButton", "OnDoubleClick", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
}

-- Lua patterns that must not match: a catalog searcher is never configured from the browser.
local bannedPatterns = {
    { "%f[%w_][%w_]*[Ss]earcher%s*[:%.]%s*Set%w*", "a catalog searcher setter" },
}

-- Animation loops: every SetLooping argument and every XML looping attribute must be NONE.
local function checkLooping(path, text)
    for arg in text:gmatch("SetLooping%s*%(%s*([^)]-)%s*%)") do
        if arg:gsub("[\"']", ""):upper() ~= "NONE" then fail(path, "SetLooping other than NONE: " .. arg) end
    end
    for value in text:gmatch("looping%s*=%s*[\"']([^\"']*)[\"']") do
        if value:upper() ~= "NONE" then fail(path, "looping other than NONE: " .. value) end
    end
end

-- Whole words that must not appear (GameTooltipTemplate and GameTooltip_Add*Line are fine).
local bannedWords = { "GameTooltip" }

-- Calls that are allowed only in one form. Each rule checks the argument text of every call.
local callRules = {
    { name = "IsOwnedFresh", what = "IsOwnedFresh without a read-only flag",
      ok = function(args) return args:match(",%s*true%s*$") ~= nil end },
    { name = "GetVendorItemAvailabilityState",
      what = "GetVendorItemAvailabilityState must be the three-argument form ending in true",
      ok = function(args) return args:match("^[^,]+,[^,]+,%s*true%s*$") ~= nil end },
    { name = "IsModifiedClick", what = "IsModifiedClick other than CHATLINK",
      ok = function(args) return args:match('^%s*"CHATLINK"%s*$') ~= nil end },
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

local function checkBans(path, text)
    for _, needle in ipairs(bannedPlain) do
        if text:find(needle, 1, true) then fail(path, "banned: " .. needle) end
    end
    for _, ban in ipairs(bannedPatterns) do
        if text:find(ban[1]) then fail(path, "banned: " .. ban[2]) end
    end
    local wordText = allowOwnTooltip(text)
    for _, word in ipairs(bannedWords) do
        if wordText:find("%f[%w_]" .. word .. "%f[^%w_]") then fail(path, "banned word: " .. word) end
    end
    checkLooping(path, text)
end

for _, path in ipairs(files) do
    local text = sources[path]
    checkBans(path, text)

    for _, rule in ipairs(callRules) do
        scanCalls(path, text, rule)
    end
end

-- The scan must catch what it claims to: run the same rules against known-bad text.
do
    local bad = {
        "CatalogStore:IsOwnedFresh(itemID)",
        "CatalogStore:IsOwnedFresh (itemID)",
        "CatalogStore:IsOwnedFresh(\n    itemID\n)",
        "local f = CatalogStore.IsOwnedFresh; f(CatalogStore, itemID)",
        "SM:GetVendorItemAvailabilityState(itemID, npcID)",
        'if IsModifiedClick("DRESSUP") then end',
        "if IsModifiedClick() then end",
        "local f = IsModifiedClick; f(\"CHATLINK\")",
    }
    for _, snippet in ipairs(bad) do
        local caught = false
        for _, rule in ipairs(callRules) do
            if not pcall(scanCalls, "probe", snippet, rule) then caught = true end
        end
        assert(caught, "the call rules missed: " .. snippet)
    end
    for _, good in ipairs({ 'CS:IsOwnedFresh(itemID, true)', 'if IsModifiedClick("CHATLINK") then end' }) do
        for _, rule in ipairs(callRules) do
            assert(pcall(scanCalls, "probe", good, rule), "the call rules rejected an allowed call: " .. good)
        end
    end

    local badText = {
        "hooksecurefunc(\"Foo\", f)",
        "tinsert(UISpecialFrames, name)",
        "UIPanelWindows[name] = {}",
        "ShowUIPanel(frame)",
        "searcher:SetSearchText(text)",
        "catalog_searcher:SetSearchText(text)",
        "local s = C_HousingCatalog.CreateCatalogSearcher()",
        "C_Map.OpenWorldMap(id)",
        "frame.TabGlowAnimation:Play()",
        "ShowAchievementFrameForAchievement(id)",
        "local r, g, b = C_Item.GetItemQualityColor(q)",
        "group:SetLooping(\"REPEAT\")",
        "group:SetLooping('bounce')",
        "<AnimationGroup name=\"A\" looping=\"REPEAT\"/>",
        "b:RegisterForClicks(\"RightButtonUp\")",
        "b:SetScript(\"OnDoubleClick\", f)",
        "if IsShiftKeyDown() then end",
        "if IsControlKeyDown() then end",
        "if IsAltKeyDown() then end",
        "local tip = CreateFrame(\"GameTooltip\", nil, UIParent)",
        "local p = SM:GetItemPresentation(itemID, { context = \"browser\" })",
    }
    for _, snippet in ipairs(badText) do
        assert(not pcall(checkBans, "probe", snippet), "the bans missed: " .. snippet)
    end
    local goodText = {
        "group:SetLooping(\"NONE\")",
        "group:SetLooping('none')",
        "<AnimationGroup name=\"A\" looping=\"NONE\"/>",
        "CreateFrame(\"GameTooltip\", \"HomesteadBrowserTooltip\", UIParent, \"GameTooltipTemplate\")",
        "b:RegisterForClicks(\"LeftButtonUp\")",
        "local search = CreateFrame(\"EditBox\", nil, band, \"SearchBoxTemplate\")",
    }
    for _, snippet in ipairs(goodText) do
        assert(pcall(checkBans, "probe", snippet), "the bans rejected allowed text: " .. snippet)
    end
end

-- Registrations: only the router listens, only while shown. Everything OnShow registers, OnHide
-- unregisters with the same arguments; nothing registers at load or Build. hs538_window runs it.
do
    for path, text in pairs(sources) do
        if path ~= "UI/Browser/Browser.lua" and (text:find("RegisterCallback", 1, true)
                or text:find("RegisterEvent", 1, true) or text:find("RegisterUnitEvent", 1, true)) then
            fail(path, "registers events or callbacks; only the router does, while shown")
        end
    end
    local router = sources["UI/Browser/Browser.lua"]
    local onShow = router:match("local function OnShow%(%)(.-)\nend")
    local onHide = router:match("local function OnHide%(%)(.-)\nend")
    assert(onShow and onHide, "the router has no OnShow or OnHide")
    local outside = router:gsub("local function OnShow%(%).-\nend", ""):gsub("local function OnHide%(%).-\nend", "")
    for _, word in ipairs({ ":RegisterCallback(", ":RegisterEvent(", ":UnregisterCallback(", ":UnregisterAllEvents(" }) do
        if outside:find(word, 1, true) then fail("UI/Browser/Browser.lua", word .. " outside OnShow and OnHide") end
    end
    local shown = 0
    for args in onShow:gmatch("HA%.Events:RegisterCallback(%b())") do
        shown = shown + 1
        if not onHide:find("HA.Events:UnregisterCallback" .. args, 1, true) then
            fail("UI/Browser/Browser.lua", "OnHide does not unregister " .. args)
        end
    end
    assert(shown >= 3, "the registration scan found too few callbacks; it is vacuous")
    assert(onShow:find(":RegisterEvent(", 1, true) and onHide:find("events:UnregisterAllEvents()", 1, true),
        "the game events are not dropped on hide")
    local event, owner = onShow:match("EventRegistry:RegisterCallback%(([%w_]+), [%w_]+, ([%w_]+)%)")
    assert(event and onHide:find("EventRegistry:UnregisterCallback(" .. event .. ", " .. owner .. ")", 1, true),
        "the text-size callback is not released on hide")
end

print("hs534_browser_invariants: ok (" .. #files .. " files)")

