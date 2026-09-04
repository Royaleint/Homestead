-- luacheck: globals assert io print loadstring ipairs select table

-- HS-291 sub-item 5: the map side panel's vendor list runs on Foundry.List.
-- UI/MapSidePanel.lua pulls in the whole addon dependency graph and cannot be
-- loaded whole, so this combines the string-gate technique from
-- hs291_phase1_templates.lua with the extract-and-loadstring harness from
-- hs210_guards.lua.

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local function read(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local source = read(root .. "/UI/MapSidePanel.lua")

local function extract(pattern, label)
    local text = source:match(pattern)
    assert(text, "could not extract " .. label)
    return text
end

-------------------------------------------------------------------------------
-- (a) String gates
-------------------------------------------------------------------------------

assert(not source:find("UIPanelScrollFrameTemplate", 1, true),
    "the legacy UIPanelScrollFrameTemplate scroll frame must be gone")
assert(not source:find("scrollChild", 1, true),
    "the scrollChild identifier must be gone, comments included")

-- The four dead sweeps, named individually: HideAllNonVendorContent is
-- deliberately kept and a prefix gate would fail on it.
for _, name in ipairs({
    "HideAllSummaryRows", "HideAllSummarySubRows",
    "HideAllItemResultRows", "HideAllSearchHeaderRows",
}) do
    assert(not source:find(name, 1, true),
        name .. " must be gone: no definition and no call site")
end

-- Reset-on-map-change was declined; it must leave no trace.
for _, name in ipairs({ "BuildRenderKey", "lastRenderKey", "ShouldResetScroll", "resetScroll" }) do
    assert(not source:find(name, 1, true),
        "the declined render-key design must leave no " .. name)
end

assert(source:find("List:New", 1, true), "the list controller must be built with List:New")
assert(source:find('elementType%s*=%s*"Frame"'), "the list must use Blizzard frame rows")
assert(source:find("extentCalculator", 1, true),
    "variable row heights require an extentCalculator")
assert(source:find('F:RequireModule("List", 1)', 1, true),
    "the List module must be resolved with F:RequireModule, not a raw _G.Foundry_1_0 index")

-- SetListRows is exactly one statement: the retained SetDataProvider call. The
-- retain flag alone proves nothing, because a ScrollToBegin on the next line
-- would keep every other gate green while every refresh jumped to the top.
local setRowsBody = extract("(local function SetListRows%(rows%).-\nend)", "SetListRows")
local collapsed = (setRowsBody:gsub("%s+", " "))
assert(collapsed == "local function SetListRows(rows) "
    .. "listScrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition) end",
    "SetListRows must contain exactly one statement: the retained SetDataProvider call")
assert(not source:find("ScrollToBegin", 1, true),
    "ScrollToBegin must not appear anywhere in UI/MapSidePanel.lua")
assert(not source:find("dataProvider:Flush", 1, true),
    "the rejected flush-and-insert shape must not come back")

-- SetListRows writes through the cached module local, and GetNativeHandles is
-- called exactly once (in CreatePanel). Zero occurrences would leave
-- listScrollBox nil; two or more mean the per-refresh handles allocation is back.
assert(source:find("listScrollBox:SetDataProvider", 1, true),
    "SetListRows must write through the cached listScrollBox")
assert(select(2, source:gsub("GetNativeHandles", "")) == 1,
    "GetNativeHandles must occur exactly once in the file, in CreatePanel")

-- Each of the five display builders publishes its rows. The asserted text is
-- the whole SetListRows(rows) call: four of the five also carry an empty-state
-- SetListRows({}) that a bare prefix find would be satisfied by.
for _, name in ipairs({ "RefreshZoneSummaries", "RefreshContinentSummaries",
                        "RefreshSearchResults", "RefreshInstanceDropSources",
                        "RefreshContent" }) do
    local body = extract("(function MapSidePanel:" .. name .. "%(.-\nend)", name)
    assert(body:find("SetListRows(rows)", 1, true),
        name .. " must publish its records with SetListRows(rows); an empty-state "
            .. "SetListRows({}) does not satisfy this gate")
end

-- The resetter releases the content frame. Without this gate the release line
-- can be deleted with every other assert, mutation and luacheck still green,
-- while each ScrollBox recycle leaks a fresh hidden frame.
local resetBody = extract("(local function ResetListElement%(container%).-\nend)", "ResetListElement")
assert(resetBody:find("FPU.ReleasePooledFrame(rowPool, content)", 1, true),
    "ResetListElement must release the content frame with FPU.ReleasePooledFrame(rowPool, content)")

-- Lua 5.1 fills a table constructor at once, so a RENDERERS table declared
-- above the render functions would hold six nils.
local rendererTablePos = source:find("local RENDERERS = {", 1, true)
assert(rendererTablePos, "RENDERERS table not found")
local lastRenderFnPos = 0
for pos in source:gmatch("()local function Render%a+Row%(") do lastRenderFnPos = pos end
assert(lastRenderFnPos > 0, "no Render...Row function definitions found")
assert(rendererTablePos > lastRenderFnPos,
    "the RENDERERS table must be declared after all six Render...Row functions")

local rendererTable = extract("local RENDERERS = {(.-)}", "the RENDERERS table body")
for _, entry in ipairs({
    "vendor = RenderVendorRow,",
    "summary = RenderSummaryRow,",
    "subrow = RenderSubRow,",
    "boss = RenderBossRow,",
    "item = RenderItemRow,",
    "header = RenderHeaderRow,",
}) do
    assert(rendererTable:find(entry, 1, true), "RENDERERS is missing: " .. entry)
end

local creatorTable = extract("local CREATORS = {(.-)}", "the CREATORS table body")
for _, entry in ipairs({
    "vendor = CreateVendorRow,",
    "summary = CreateSummaryRow,",
    "subrow = CreateSummarySubRow,",
    "boss = CreateBossRow,",
    "item = CreateItemResultRow,",
    "header = CreateSearchHeaderRow,",
}) do
    assert(creatorTable:find(entry, 1, true), "CREATORS is missing: " .. entry)
end

-- The plan's one deliberate parity deviation, pinned as a whole line so it can
-- be neither dropped nor silently widened.
local MAP_INFO_NIL_LINE = [[
    if not mapInfo then HideAllNonVendorContent() SetListRows({}) expandedSummaryMapID = nil HideProgressBar() currentDisplayLevel = "zone" return end]]
assert(source:find(MAP_INFO_NIL_LINE, 1, true),
    "the mapInfo-nil early return must clear the list with SetListRows({})")

assert(source:find("ICONS_PER_ROW", 1, true), "the ICONS_PER_ROW module constant must exist")

for _, name in ipairs({ "PopulateItemGrid", "PopulateBossItemGrid" }) do
    local body = extract("(local function " .. name .. "%(.-\nend)", name)
    assert(not body:find("local iconsPerRow", 1, true),
        name .. " must read ICONS_PER_ROW, not redeclare a local iconsPerRow")
end

print("hs291_mapsidepanel_list: string gates ok")

-------------------------------------------------------------------------------
-- (b) Combat guards: six anchors plus the count
-------------------------------------------------------------------------------

local GUARDS = {
    { "G1 (preview map-shift reapply, line 214)", [[
            if panelFrame and panelFrame:IsShown() and not isPoppedOut then
                if InCombatLockdown() then
                    pendingDockedAction = "apply"]] },
    { "G2 (ShowPanel, apply docked integration)", [[
    -- Defer all docked map mutations until combat ends
    if InCombatLockdown() then
        pendingDockedAction = "apply"]] },
    { "G3 (HidePanel, defer map restoration)", [[
    -- Defer map restoration until combat ends
    if InCombatLockdown() then
        pendingDockedAction = "remove"]] },
    { "G4 (close detached, restore all map modifications)", [[
    -- 2. Restore all map modifications
    if InCombatLockdown() then
        pendingDockedAction = "remove"]] },
    { "G5 (map closed, defer restoration)", [[
                if InCombatLockdown() then
                    -- Closing during combat; defer restoration. Cancel any pending]] },
    { "G6 (map maximized, external reposition)", [[
                    if InCombatLockdown() then
                        mapShifted = false
                        savedMapPoint = nil
                        pendingDockedAction = "clear"]] },
}

for _, guard in ipairs(GUARDS) do
    assert(source:find(guard[2], 1, true),
        "guard " .. guard[1] .. " is missing or was edited")
end

-- The count alone cannot catch a guard deleted here and an unrelated one added
-- elsewhere; the six anchors above are what close that gap.
assert(select(2, source:gsub("if InCombatLockdown%(%) then", "")) == 6,
    "UI/MapSidePanel.lua must carry exactly six combat guards")

print("hs291_mapsidepanel_list: combat guards ok")

-------------------------------------------------------------------------------
-- (c) Renderer bodies: no re-entry into the data path
-------------------------------------------------------------------------------

for _, name in ipairs({ "Vendor", "Summary", "Sub", "Boss", "Item", "Header" }) do
    local body = extract("(local function Render" .. name .. "Row%(.-\nend)", "Render" .. name .. "Row")
    assert(not body:find("RefreshContent", 1, true),
        "Render" .. name .. "Row must not call RefreshContent")
    assert(not body:find("SetListRows", 1, true),
        "Render" .. name .. "Row must not call SetListRows")
end

print("hs291_mapsidepanel_list: renderer bodies ok")

-------------------------------------------------------------------------------
-- (d) Height arithmetic, extracted from source and executed
-------------------------------------------------------------------------------

-- The constants are extracted rather than hard-coded: a test that pinned 24 for
-- ITEM_GRID_INSET would keep passing after someone changed it in the module,
-- which is the drift this gate exists to catch.
local chunkParts = {}
for _, name in ipairs({ "PANEL_WIDTH", "PADDING", "ITEM_ICON_SIZE", "ITEM_ICON_PAD",
                        "ITEM_GRID_INSET", "ITEM_RESULT_LINE_HEIGHT" }) do
    assert(select(2, source:gsub("\nlocal " .. name .. " = ", "")) == 1,
        "expected exactly one module-scope declaration of " .. name)
    chunkParts[#chunkParts + 1] =
        extract("\n(local " .. name .. " = [^\n]*)", name .. " declaration")
end

chunkParts[#chunkParts + 1] = extract(
    "\n(local ICONS_PER_ROW = math%.floor%(.-\nif ICONS_PER_ROW < 1 then ICONS_PER_ROW = 1 end)",
    "the ICONS_PER_ROW declaration and its clamp")
chunkParts[#chunkParts + 1] = extract(
    "\n(local function ComputeItemGridHeight%(itemCount%).-\nend)", "ComputeItemGridHeight")
chunkParts[#chunkParts + 1] = extract(
    "\n(local function ComputeItemSourceListHeight%(sourceCount%).-\nend)",
    "ComputeItemSourceListHeight")
chunkParts[#chunkParts + 1] =
    "return ICONS_PER_ROW, ComputeItemGridHeight, ComputeItemSourceListHeight"

local ICONS_PER_ROW, ComputeItemGridHeight, ComputeItemSourceListHeight =
    assert(loadstring(table.concat(chunkParts, "\n"), "height-helpers-extract"))()

-- Asserted before any height, because both icon-positioning loops read this
-- same constant and this is the single gate that covers the column count.
assert(ICONS_PER_ROW == 6, "ICONS_PER_ROW must be 6, got " .. tostring(ICONS_PER_ROW))

for _, case in ipairs({ { 0, 0 }, { 1, 34 }, { 6, 34 }, { 7, 65 } }) do
    local got = ComputeItemGridHeight(case[1])
    assert(got == case[2], "ComputeItemGridHeight(" .. case[1] .. ") must be "
        .. case[2] .. ", got " .. tostring(got))
end

for _, case in ipairs({ { 0, 22 }, { 1, 22 }, { 3, 58 } }) do
    local got = ComputeItemSourceListHeight(case[1])
    assert(got == case[2], "ComputeItemSourceListHeight(" .. case[1] .. ") must be "
        .. case[2] .. ", got " .. tostring(got))
end

print("hs291_mapsidepanel_list: height arithmetic ok")
