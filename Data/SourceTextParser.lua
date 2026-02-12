--[[
    Homestead - SourceTextParser
    Pure Lua 5.1 string parser for WoW Housing Catalog sourceText

    sourceText format (from C_HousingCatalog API):
      Block separator: |n|n
      Field separator: |n
      Currency hyperlinks: |Hcurrency:<id>|h|h
      Source types: Vendor, Quest, Achievement, Profession, Drop

    Two-tier parsing:
      Tier 1 (structural): All locales. Splits blocks/lines, extracts currency hyperlinks.
      Tier 2 (typed): enUS/enGB. Maps prefixes to typed fields (vendor, zone, cost, etc.).

    No WoW API calls. No SavedVariables access.
]]

local addonName, HA = ...

local SourceTextParser = {}
HA.SourceTextParser = SourceTextParser

local strmatch = string.match
local strfind = string.find
local strsub = string.sub
local strgmatch = string.gmatch
local tonumber = tonumber
local table_insert = table.insert

-------------------------------------------------------------------------------
-- Local Helpers
-------------------------------------------------------------------------------

-- Remove leading and trailing whitespace from a string
local function Trim(s)
    if not s then return nil end
    return strmatch(s, "^%s*(.-)%s*$")
end

-- Strip WoW color codes from text, preserving |n separators and |H hyperlinks
-- |cAARRGGBB (10 chars) starts colored text, |r resets
local function StripColorCodes(text)
    if not text then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

-- Strip WoW hyperlinks from text, returning visible text only
-- Hyperlink format: |Htype:data|hvisibleText|h
-- Currency cost format has empty display text: |Hcurrency:1560|h|h
local function StripHyperlinks(text)
    if not text then return nil end
    -- Replace |Htype:data|hvisibleText|h with just visibleText
    local result = text:gsub("|H[^|]*|h([^|]*)|h", "%1")
    return result
end

-- Strip WoW texture escape sequences: |TPath:height:width:...|t
local function StripTextureEscapes(text)
    if not text then return nil end
    return text:gsub("|T[^|]*|t", "")
end

-- Parse a cost field value into a cost table matching VendorData format
-- "100" -> {gold = 1000000}  (100 gold * 10000 copper/gold)
-- "100|TInterface\MoneyFrame\UI-GoldIcon:...|t" -> {gold = 1000000}
-- "200|Hcurrency:1560|h|h" -> {currencies = {{id = 1560, amount = 200}}}
local function ParseCostField(costText)
    if not costText then return nil end

    -- Check for currency hyperlink first
    local amount, currencyID = strmatch(costText, "(%d+)%s*|Hcurrency:(%d+)|h")
    if currencyID then
        currencyID = tonumber(currencyID)
        amount = tonumber(amount)
        if currencyID and amount then
            return {currencies = {{id = currencyID, amount = amount}}}
        end
    end

    -- Strip texture escapes (gold icon: |TInterface\MoneyFrame\UI-GoldIcon:...|t)
    local cleaned = StripTextureEscapes(costText)
    if cleaned then
        local goldAmount = strmatch(cleaned, "^%s*(%d[%d,]*)%s*$")
        if goldAmount then
            -- Remove comma separators (e.g., "1,000" -> "1000")
            goldAmount = goldAmount:gsub(",", "")
            goldAmount = tonumber(goldAmount)
            if goldAmount then
                return {gold = goldAmount * 10000}
            end
        end
    end

    return nil
end

-- Parse a structural block (Tier 1 — all locales)
-- Extracts raw key:value pairs and currency hyperlinks without locale knowledge
local function ParseStructuralBlock(block)
    local source = {
        sourceType = "structural",
        rawLines = {},
        currencyLinks = {},
    }

    -- Extract all currency hyperlinks from the entire block
    for currID in strgmatch(block, "|Hcurrency:(%d+)|h") do
        table_insert(source.currencyLinks, tonumber(currID))
    end

    -- Split block into lines on |n
    local lineStart = 1
    local blockLen = #block
    while lineStart <= blockLen do
        local sepPos = strfind(block, "|n", lineStart, true)
        local line
        if sepPos then
            line = strsub(block, lineStart, sepPos - 1)
            lineStart = sepPos + 2
        else
            line = strsub(block, lineStart)
            lineStart = blockLen + 1
        end

        line = Trim(line)
        if line and line ~= "" then
            -- Try to split on first colon for key:value
            local key, value = strmatch(line, "^([^:]+):%s*(.*)")
            if key then
                table_insert(source.rawLines, {key = Trim(key), value = Trim(StripHyperlinks(value))})
            else
                table_insert(source.rawLines, {key = line, value = ""})
            end
        end
    end

    -- Use first line as name if available
    if source.rawLines[1] then
        source.name = source.rawLines[1].key
        if source.rawLines[1].value ~= "" then
            source.name = source.name .. ": " .. source.rawLines[1].value
        end
    end

    -- If no currency links found, clear the table
    if #source.currencyLinks == 0 then
        source.currencyLinks = nil
    end

    return source
end

-- Parse a typed source block (Tier 2 — enUS/enGB)
-- Maps known prefixes to semantic fields
local function ParseSourceBlock(block, profile)
    if not profile then
        return ParseStructuralBlock(block)
    end

    local source = {}

    -- Split block into lines on |n
    local lines = {}
    local lineStart = 1
    local blockLen = #block
    while lineStart <= blockLen do
        local sepPos = strfind(block, "|n", lineStart, true)
        local line
        if sepPos then
            line = strsub(block, lineStart, sepPos - 1)
            lineStart = sepPos + 2
        else
            line = strsub(block, lineStart)
            lineStart = blockLen + 1
        end
        line = Trim(line)
        if line and line ~= "" then
            table_insert(lines, line)
        end
    end

    if #lines == 0 then
        return nil
    end

    -- First line determines source type
    local firstLine = lines[1]
    local matched = false

    for prefix, sourceType in pairs(profile.sourceTypes) do
        if strsub(firstLine, 1, #prefix) == prefix then
            source.sourceType = sourceType
            source.name = Trim(strsub(firstLine, #prefix + 1))
            matched = true
            break
        end
    end

    if not matched then
        -- Unknown prefix: store entire block as name
        source.sourceType = "unknown"
        source.name = block
        return source
    end

    -- Process remaining lines as field:value pairs
    for i = 2, #lines do
        local line = lines[i]
        for prefix, fieldName in pairs(profile.fields) do
            if strsub(line, 1, #prefix) == prefix then
                local rawValue = Trim(strsub(line, #prefix + 1))

                if fieldName == "zone" then
                    source.zone = StripHyperlinks(rawValue)

                elseif fieldName == "faction" then
                    -- Split on " - " for faction + standing
                    local dashPos = strfind(rawValue, " - ", 1, true)
                    if dashPos then
                        source.faction = Trim(strsub(rawValue, 1, dashPos - 1))
                        source.standing = Trim(strsub(rawValue, dashPos + 3))
                    else
                        source.faction = rawValue
                    end

                elseif fieldName == "cost" then
                    source.cost = ParseCostField(rawValue)

                elseif fieldName == "category" then
                    source.category = StripHyperlinks(rawValue)
                end

                break
            end
        end

        -- Unrecognized field lines are silently ignored in typed mode
    end

    -- Profession special case: name doubles as professionReq
    if source.sourceType == "profession" then
        source.professionReq = source.name
    end

    return source
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Get locale profile for typed parsing, or nil for structural-only
function SourceTextParser:GetLocaleProfile(locale)
    if not locale then return nil end
    local profiles = HA.SourceTextLocaleProfiles and HA.SourceTextLocaleProfiles.Profiles
    if not profiles then return nil end
    return profiles[locale]
end

-- Main entry point: parse a sourceText string into structured sources
-- Returns {sources = {ParsedSource, ...}} or nil
function SourceTextParser:ParseSourceText(sourceText, locale)
    if not sourceText or sourceText == "" then
        return nil
    end

    -- Strip color codes before parsing (API wraps labels in |cFFFD200...|r)
    sourceText = StripColorCodes(sourceText)

    local profile = self:GetLocaleProfile(locale)
    local sources = {}

    -- Split on |n|n (block separator)
    local blockStart = 1
    local textLen = #sourceText
    while blockStart <= textLen do
        local sepPos = strfind(sourceText, "|n|n", blockStart, true)
        local block
        if sepPos then
            block = strsub(sourceText, blockStart, sepPos - 1)
            blockStart = sepPos + 4
        else
            block = strsub(sourceText, blockStart)
            blockStart = textLen + 1
        end

        block = Trim(block)
        if block and block ~= "" then
            local parsed = ParseSourceBlock(block, profile)
            if parsed then
                table_insert(sources, parsed)
            end
        end
    end

    if #sources == 0 then
        return nil
    end

    return {sources = sources}
end

-------------------------------------------------------------------------------
-- Built-in Tests
-------------------------------------------------------------------------------

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
        local input = "|cFFFD200Vendor:|r Meridelle Lightspark|n|cFFFD200Zone:|r Dornogal|n|cFFFD200Cost:|r 200|Hcurrency:3056|h|h"
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
        local input = "|cFFFD200Vendor:|r Klasa|n|cFFFD200Zone:|r Founder's Point|n|cFFFD200Cost:|r 10|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:0|t"
        local result = self:ParseSourceText(input, locale)
        check("T8 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T8 sourceType", s.sourceType, "vendor")
            check("T8 name", s.name, "Klasa")
            check("T8 cost gold", s.cost and s.cost.gold, 100000)
        end
    end

    -- Test 9: Unknown prefix
    do
        local input = "Treasure: Hidden Chest|nZone: Duskwood"
        local result = self:ParseSourceText(input, locale)
        check("T9 result not nil", result ~= nil, true)
        if result then
            local s = result.sources[1]
            check("T9 sourceType", s.sourceType, "unknown")
            check("T9 name contains input", strfind(s.name, "Treasure: Hidden Chest", 1, true) ~= nil, true)
        end
    end

    print(("SourceTextParser: %d/%d tests passed, %d failed"):format(testCount - failCount, testCount, failCount))
    return pass, failCount
end
