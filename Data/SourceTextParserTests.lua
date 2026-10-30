--[[
    Homestead - SourceTextParser built-in self-test suite

    Dev-only home for SourceTextParser:RunTests and the /hs debug parsertest
    command. Split out of Data/SourceTextParser.lua so the player addon does
    not carry the test fixtures. This file is never listed in Homestead.toc and
    is excluded from the packaged zip (.pkgmeta); the DevBuild TOC loads it
    after Data/SourceTextParser.lua.

    The tests only call SourceTextParser's public methods, so nothing in the
    parser had to be exposed for the split.

    Command registration waits for PLAYER_LOGIN, by which point core.lua's
    OnInitialize has run and HousingAddon.commands exists (see
    Core/DevMemoryDiagnostics.lua). The registration is skipped when the file
    is loaded without the addon core (the offline test harness).
]]

local _, HA = ...

local SourceTextParser = HA.SourceTextParser

function SourceTextParser:RunTests()
    local pass = true
    local failCount = 0
    local testCount = 0

    local function check(name, got, expected)
        testCount = testCount + 1
        if got ~= expected then
            print("|cffff4444FAIL|r " .. name .. ": expected [" .. tostring(expected) .. "], got [" .. tostring(got) .. "]")
            pass = false
            failCount = failCount + 1
        else
            print("|cff44ff44PASS|r " .. name)
        end
    end

    local locale = "enUS"

    -- Test 1: Single vendor with faction
    do
        local input = "Vendor: Captain Lancy Revshon|nZone: Stormwind City|nFaction: Stormwind - Honored|nCost: 100"
        local result = self:ParseSourceText(input, locale)
        check("T1 result not nil", result ~= nil, true)
        if result then
            check("T1 source count", #result.sources, 1)
            local s = result.sources[1]
            check("T1 sourceType", s.sourceType, "vendor")
            check("T1 name", s.name, "Captain Lancy Revshon")
            check("T1 zone", s.zone, "Stormwind City")
            check("T1 faction", s.faction, "Stormwind")
            check("T1 standing", s.standing, "Honored")
            check("T1 cost.gold", s.cost and s.cost.gold, 1000000)
        end
    end

    -- Test 2: Multi-source (Quest + Vendor)
    do
        local input = "Quest: Axis of Awful|nZone: Loch Modan|n|nVendor: Drac Roughcut|nZone: Loch Modan|nCost: 300"
        local result = self:ParseSourceText(input, locale)
        check("T2 result not nil", result ~= nil, true)
        if result then
            check("T2 source count", #result.sources, 2)
            local s1 = result.sources[1]
            check("T2 s1 sourceType", s1.sourceType, "quest")
            check("T2 s1 name", s1.name, "Axis of Awful")
            check("T2 s1 zone", s1.zone, "Loch Modan")
            local s2 = result.sources[2]
            check("T2 s2 sourceType", s2.sourceType, "vendor")
            check("T2 s2 name", s2.name, "Drac Roughcut")
            check("T2 s2 zone", s2.zone, "Loch Modan")
            check("T2 s2 cost.gold", s2.cost and s2.cost.gold, 3000000)
        end
    end

    -- Test 3: Currency cost
    do
        local input = "Vendor: Arcanist Peroleth|nZone: Zuldazar|nCost: 200|Hcurrency:1560|h|h"
        local result = self:ParseSourceText(input, locale)
        check("T3 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T3 sourceType", s.sourceType, "vendor")
            check("T3 name", s.name, "Arcanist Peroleth")
            check("T3 zone", s.zone, "Zuldazar")
            check("T3 no gold", s.cost and s.cost.gold, nil)
            check("T3 has currencies", s.cost and s.cost.currencies ~= nil, true)
            if s.cost and s.cost.currencies then
                check("T3 currency count", #s.cost.currencies, 1)
                check("T3 currency id", s.cost.currencies[1].id, 1560)
                check("T3 currency amount", s.cost.currencies[1].amount, 200)
            end
        end
    end

    -- Test 4: Profession
    do
        local input = "Profession: Khaz Algar Cooking (80)"
        local result = self:ParseSourceText(input, locale)
        check("T4 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T4 sourceType", s.sourceType, "profession")
            check("T4 name", s.name, "Khaz Algar Cooking (80)")
            check("T4 professionReq", s.professionReq, "Khaz Algar Cooking (80)")
        end
    end

    -- Test 5: Drop
    do
        local input = "Drop: Shade of Xavius|nZone: Darkheart Thicket"
        local result = self:ParseSourceText(input, locale)
        check("T5 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T5 sourceType", s.sourceType, "drop")
            check("T5 name", s.name, "Shade of Xavius")
            check("T5 zone", s.zone, "Darkheart Thicket")
        end
    end

    -- Test 6: nil and empty
    do
        local r1 = self:ParseSourceText(nil, locale)
        check("T6 nil input", r1, nil)
        local r2 = self:ParseSourceText("", locale)
        check("T6 empty input", r2, nil)
    end

    -- Test 7: Color-coded sourceText (real API format)
    do
        local input = "|cFFFFD200Vendor:|r Meridelle Lightspark|n|cFFFFD200Zone:|r Dornogal|n|cFFFFD200Cost:|r 200|Hcurrency:3056|h|h"
        local result = self:ParseSourceText(input, locale)
        check("T7 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T7 sourceType", s.sourceType, "vendor")
            check("T7 name", s.name, "Meridelle Lightspark")
            check("T7 zone", s.zone, "Dornogal")
            check("T7 has currencies", s.cost and s.cost.currencies ~= nil, true)
        end
    end

    -- Test 8: Gold cost with texture escape (gold icon)
    do
        local input = "|cFFFFD200Vendor:|r Klasa|n|cFFFFD200Zone:|r Founder's Point|n|cFFFFD200Cost:|r 10|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:0|t"
        local result = self:ParseSourceText(input, locale)
        check("T8 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T8 sourceType", s.sourceType, "vendor")
            check("T8 name", s.name, "Klasa")
            check("T8 cost gold", s.cost and s.cost.gold, 100000)
        end
    end

    -- Test 9: Unknown prefix (still unmodeled after the class fixes — proves the
    -- "not matched" branch, and the class-wide invariant below, still cover
    -- whatever the next unrecognized prefix turns out to be)
    do
        local input = "Mystery: Hidden Chest|nZone: Duskwood"
        local result = self:ParseSourceText(input, locale)
        check("T9 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T9 sourceType", s.sourceType, "unknown")
            check("T9 name contains input", string.find(s.name, "Mystery: Hidden Chest", 1, true) ~= nil, true)
        end
    end

    -- Test 10: source-text class 1 — Treasure prefix (items 243106, 245282,
    -- 246416, 251912, 262616, 263211)
    do
        local input = "Treasure: Gift of the Phoenix|nZone: Eversong Woods"
        local result = self:ParseSourceText(input, locale)
        check("T10 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T10 sourceType", s.sourceType, "treasure")
            check("T10 name", s.name, "Gift of the Phoenix")
            check("T10 zone", s.zone, "Eversong Woods")
        end
    end

    -- Test 11: source-text class 2 — "Vendors:" plural, multi-vendor name plus
    -- zone/faction/cost all riding the same block (item 251494)
    do
        local input = "Vendors: Selfira Ambergrove, Sylvia Hartshorn|nZone: Val'sharah|nFaction: Dreamweavers - Friendly|nCost: 200|Hcurrency:1220|h|h"
        local result = self:ParseSourceText(input, locale)
        check("T11 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T11 sourceType", s.sourceType, "vendor")
            check("T11 name", s.name, "Selfira Ambergrove, Sylvia Hartshorn")
            check("T11 zone", s.zone, "Val'sharah")
            check("T11 faction", s.faction, "Dreamweavers")
            check("T11 standing", s.standing, "Friendly")
            check("T11 currency id", s.cost and s.cost.currencies and s.cost.currencies[1].id, 1220)
            check("T11 currency amount", s.cost and s.cost.currencies and s.cost.currencies[1].amount, 200)
        end
    end

    -- Test 12: source-text class 3 (discriminating) — space-separated fields with
    -- no |n at all (decorID 714 / item 245284). Pre-fix, the line-split at
    -- the top of ParseSourceBlock yields one line and everything past
    -- "Vendor: " — including "Zone: Silvermoon City  Cost: ..." — lands in
    -- name, so this fails on the old parser rather than passing vacuously.
    do
        local input = "Vendor: Dethelin  Zone: Silvermoon City  Cost: 3000|Hcurrency:2815|h|h"
        local result = self:ParseSourceText(input, locale)
        check("T12 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T12 sourceType", s.sourceType, "vendor")
            check("T12 name", s.name, "Dethelin")
            check("T12 zone", s.zone, "Silvermoon City")
            check("T12 currency id", s.cost and s.cost.currencies and s.cost.currencies[1].id, 2815)
            check("T12 currency amount", s.cost and s.cost.currencies and s.cost.currencies[1].amount, 3000)
        end
    end

    -- Class-wide invariant: once a source is successfully typed
    -- (sourceType ~= "unknown"), its name must never contain a field label,
    -- whatever the input shape looked like. This is the actual spec — fixing
    -- the three shapes above without asserting this property leaves the next
    -- unknown prefix to fail the same silent way. "unknown" sources are
    -- exempt by design: dumping the whole raw block into name IS the
    -- intentional "parse failed, here's the evidence" signal (Test 9), not a
    -- successful-but-corrupted parse.
    -- Checked over every source produced by every test above, not just the
    -- rows that motivated the fix.
    do
        local FIELD_LABELS = {"Zone", "Cost", "Faction", "Standing", "Category"}
        -- A name that lost every character to a bad split (e.g. an embedded
        -- field label at position 1) satisfies "contains no field label"
        -- vacuously — reject empty names too so that failure mode is loud
        -- instead of silently passing.
        local function nameIsValid(name)
            if not name or name == "" then return false end
            for _, label in ipairs(FIELD_LABELS) do
                if string.find(name, "%f[%a]" .. label .. ":") then
                    return false
                end
            end
            return true
        end

        local allTypedNames = {}
        for _, input in ipairs({
            "Vendor: Captain Lancy Revshon|nZone: Stormwind City|nFaction: Stormwind - Honored|nCost: 100",
            "Quest: Axis of Awful|nZone: Loch Modan|n|nVendor: Drac Roughcut|nZone: Loch Modan|nCost: 300",
            "Vendor: Arcanist Peroleth|nZone: Zuldazar|nCost: 200|Hcurrency:1560|h|h",
            "Profession: Khaz Algar Cooking (80)",
            "Drop: Shade of Xavius|nZone: Darkheart Thicket",
            "|cFFFFD200Vendor:|r Meridelle Lightspark|n|cFFFFD200Zone:|r Dornogal|n|cFFFFD200Cost:|r 200|Hcurrency:3056|h|h",
            "|cFFFFD200Vendor:|r Klasa|n|cFFFFD200Zone:|r Founder's Point|n|cFFFFD200Cost:|r 10|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:0|t",
            "Mystery: Hidden Chest|nZone: Duskwood",
            "Treasure: Gift of the Phoenix|nZone: Eversong Woods",
            "Vendors: Selfira Ambergrove, Sylvia Hartshorn|nZone: Val'sharah|nFaction: Dreamweavers - Friendly|nCost: 200|Hcurrency:1220|h|h",
            "Vendor: Dethelin  Zone: Silvermoon City  Cost: 3000|Hcurrency:2815|h|h",
        }) do
            local result = self:ParseSourceText(input, locale)
            if result then
                for _, s in ipairs(result.sources) do
                    if s.name and s.sourceType ~= "unknown" then
                        allTypedNames[#allTypedNames + 1] = s.name
                    end
                end
            end
        end

        for _, name in ipairs(allTypedNames) do
            check("class-wide: name is non-empty with no field label [" .. name .. "]", nameIsValid(name), true)
        end
    end

    print(("SourceTextParser: %d/%d tests passed, %d failed"):format(testCount - failCount, testCount, failCount))
    return pass, failCount
end

if HA.Addon and CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function()
        HA.Addon.commands:Register({ name = "debug parsertest",
            help = "Run SourceTextParser's built-in self-test suite.",
            handler = function() SourceTextParser:RunTests() end })
    end)
end
