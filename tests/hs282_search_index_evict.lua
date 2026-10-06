-- luacheck: globals assert loadfile loadstring print io C_Item

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-282 sub-item G: evict the SearchProvider index when the map side panel
-- closes -- UI/MapSidePanel.lua's CreatePanel wires an OnHide hook on the
-- panel frame that calls the existing HA.SearchProvider:Invalidate()
-- (UI/SearchProvider.lua:65-68, nils searchIndex + bumps indexRevision).
-- Reclaims ~2.2 MB in the non-searching steady state; rebuild stays
-- automatic via BuildIndex()'s existing lazy rebuild on the next Search
-- (~20ms worst case, accepted by Rawb against the reclaim). No new
-- eviction machinery, no timers, no events -- this proves the existing
-- pieces compose correctly, not new mechanism.
--
-- Part 1: SearchProvider itself -- Search builds the index, Invalidate()
--   nils it, the next Search for the same query rebuilds and returns
--   results IDENTICAL (deep-compare) to the pre-eviction results, and the
--   revision counter increments by exactly 1 across the evict (and NOT on
--   a plain Search).
-- Part 2: MapSidePanel.lua's OnHide hook -- source-text assertions that
--   exactly one HookScript("OnHide", ...) call site exists and is guarded
--   the same way the rest of the file guards optional-module calls, plus
--   an extract-and-loadstring behavioral test of the hook body itself
--   (same technique as hs210_guards.lua / hs222_223_batch.lua's
--   ScheduleContentRefresh/pool-key extractions, since MapSidePanel.lua
--   pulls in the full addon/UI dependency graph and can't be loaded
--   wholesale in this harness). The frame itself actually firing OnHide on
--   a real Show/Hide transition is a UI-frame dependency this harness
--   cannot exercise -- that composition is verified at Gate 2 in-game.
-------------------------------------------------------------------------------

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-------------------------------------------------------------------------------
-- Part 1: SearchProvider build / evict / rebuild-identical / revision-bump
-------------------------------------------------------------------------------

do
    local HA = {}

    local vendors = {
        { npcID = 90001, name = "Bramblewick the Trader", zone = "Dornogal", subzone = "", faction = "Neutral" },
        { npcID = 90002, name = "Old Man Higgins", zone = "Elwynn Forest", subzone = "Goldshire", faction = "Alliance" },
    }
    local itemsByNpc = {
        [90001] = { 100001, 100002 },
        [90002] = { 100003 },
    }
    local itemNames = {
        [100001] = "Cozy Rug",
        [100002] = "Brass Lantern",
        [100003] = "Woolen Curtain",
    }

    HA.VendorData = {
        GetAllVendors = function() return vendors end,
        GetMergedItemIDs = function(_, vendor) return itemsByNpc[vendor.npcID] end,
    }
    HA.Events = { RegisterCallback = function() end }

    C_Item = { GetItemNameByID = function(itemID) return itemNames[itemID] end }

    assert(loadfile(root .. "/UI/SearchProvider.lua"))("Homestead", HA)
    local SP = HA.SearchProvider
    SP:Initialize()  -- sets the module's VD reference; BuildIndex is a no-op without it

    -- (a) Search builds the index.
    assert(SP:GetDebugIndex() == nil, "index must not exist before the first Search")
    local revisionBefore = SP:GetRevision()
    local resultsBefore = SP:Search("rug")
    assert(SP:GetDebugIndex() ~= nil, "the first Search must build the index (GetDebugIndex non-nil)")
    assert(#resultsBefore == 1, "expected exactly one vendor match for 'rug', got " .. #resultsBefore)
    assert(resultsBefore[1].vendor.npcID == 90001, "expected the match to be Cozy Rug's vendor")
    assert(SP:GetRevision() == revisionBefore, "a plain Search must not change the revision")

    -- (b) Invalidate() nils the index.
    SP:Invalidate()
    assert(SP:GetDebugIndex() == nil, "Invalidate() must nil the index (GetDebugIndex nil)")

    -- (d) revision increments across the evict, by exactly 1.
    assert(SP:GetRevision() == revisionBefore + 1,
        "Invalidate() must increment the revision by exactly 1, got delta " ..
        (SP:GetRevision() - revisionBefore))

    -- (c) the next Search rebuilds and returns results identical to pre-eviction.
    local resultsAfter = SP:Search("rug")
    assert(SP:GetDebugIndex() ~= nil, "the post-evict Search must rebuild the index")
    assert(deepEqual(resultsBefore, resultsAfter),
        "results for the same query must be identical before and after an eviction/rebuild cycle")

    print("hs282_search_index_evict: Part 1 (SearchProvider build/evict/rebuild/revision) ok")
end

-------------------------------------------------------------------------------
-- Part 2: MapSidePanel.lua's OnHide hook -- wiring + extracted behavior
-------------------------------------------------------------------------------

do
    local mapSidePanelSource = assert(io.open(root .. "/UI/MapSidePanel.lua", "r")):read("*a")

    -- Exactly one hide-path convergence point: a single HookScript("OnHide", ...)
    -- registration on the panel frame. (Per the HS-282 sub-item G design, this
    -- is deliberate -- every Hide()/Toggle()/CloseDetached()/map-closed/
    -- map-maximized path ends by calling panel:Hide(), so OnHide is the one
    -- point they all converge on; adding a second call site would defeat that.)
    local _, hookCount = mapSidePanelSource:gsub('panel:HookScript%("OnHide",', "")
    assert(hookCount == 1,
        "expected exactly one panel:HookScript(\"OnHide\", ...) registration, got " .. hookCount)

    -- Guarded the same way the rest of the file guards optional-module calls
    -- (e.g. the HA.SearchProvider.Initialize call at file scope).
    assert(mapSidePanelSource:find(
        "if HA%.SearchProvider and HA%.SearchProvider%.Invalidate then", 1) ~= nil,
        "expected the OnHide hook to guard on HA.SearchProvider and its Invalidate method")
    assert(mapSidePanelSource:find("HA%.SearchProvider:Invalidate%(%)", 1) ~= nil,
        "expected the OnHide hook to call HA.SearchProvider:Invalidate()")

    -- Extract the hook's own function body and run it directly -- same
    -- extract-and-loadstring technique as hs210_guards.lua's
    -- ScheduleContentRefresh extraction. MapSidePanel.lua uses `local _, HA = ...`
    -- for its addon-table upvalue, so the wrapper chunk reproduces that.
    local hookBody = mapSidePanelSource:match(
        'panel:HookScript%("OnHide", (function%(%).-\n%s*end)%)')
    assert(hookBody ~= nil, "could not extract the OnHide hook's function body from MapSidePanel.lua")

    local chunk = "local _, HA = ...\nreturn " .. hookBody
    local buildOnHideFn = assert(loadstring(chunk, "OnHide-hook-extract"))

    -- Each buildOnHideFn call passes (addonName, HA) to match the real file's
    -- `local _, HA = ...` unpacking.

    -- Case A: HA.SearchProvider present with Invalidate -- must call it exactly once.
    do
        local invalidateCalls = 0
        local stubHA = { SearchProvider = { Invalidate = function() invalidateCalls = invalidateCalls + 1 end } }
        local onHideFn = buildOnHideFn("Homestead", stubHA)
        onHideFn()
        assert(invalidateCalls == 1,
            "the OnHide hook must call SearchProvider:Invalidate() exactly once, got " .. invalidateCalls)
    end

    -- Case B: HA.SearchProvider absent (module not yet loaded/init'd) -- must
    -- no-op without erroring.
    do
        local stubHA = {}
        local onHideFn = buildOnHideFn("Homestead", stubHA)
        onHideFn()  -- must not error
    end

    -- Case C: HA.SearchProvider present but without an Invalidate method --
    -- must no-op without erroring (mirrors the same guard style used
    -- elsewhere in this file for optional/partially-loaded modules).
    do
        local stubHA = { SearchProvider = {} }
        local onHideFn = buildOnHideFn("Homestead", stubHA)
        onHideFn()  -- must not error
    end

    print("hs282_search_index_evict: Part 2 (OnHide hook wiring + extracted behavior) ok")
end

print("hs282_search_index_evict: done")
