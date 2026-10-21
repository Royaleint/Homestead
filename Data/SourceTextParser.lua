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

local _, HA = ...

local SourceTextParser = {}
HA.SourceTextParser = SourceTextParser

-- Bump whenever a parsing-logic change should force already-stored items to
-- re-parse even though their sourceText hash is unchanged (see
-- SourceTextScanner:ProcessScannedItem's parserVersion check). First value —
-- not a bump from a prior version, since no such gate existed before.
SourceTextParser.VERSION = 1

local strmatch = string.match
local strfind = string.find
local strsub = string.sub
local strgmatch = string.gmatch
local tonumber = tonumber
local table_insert = table.insert
local table_sort = table.sort

-------------------------------------------------------------------------------
-- Local Helpers
-------------------------------------------------------------------------------

-- Remove leading and trailing whitespace from a string
local function Trim(s)
    if not s then return nil end
    return strmatch(s, "^%s*(.-)%s*$")
end

-- Escape Lua pattern magic characters so a literal profile prefix can be
-- concatenated into a pattern (SplitEmbeddedFields below) without being
-- misread as a pattern fragment. enUS/enGB's prefixes have no magic
-- characters today, but the file header promises a new locale needs only a
-- new Profiles entry — this keeps that promise true for one that does.
local function EscapePattern(s)
    return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Strip WoW color codes from text, preserving |n separators and |H hyperlinks
-- |cAARRGGBB (10 chars) starts colored text, |r resets. |cnNAMED_COLOR: is the
-- WoW 10.x+ named-color form (Overlay/Tooltips.lua strips it from this same
-- sourceText data — mirrored here so labels arriving in |cn form don't
-- silently degrade to "unknown" instead of parsing).
local function StripColorCodes(text)
    if not text then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|cn[^:]*:", "")
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
    local amount, currencyID = strmatch(costText, "(%d[%d,]*)%s*|Hcurrency:(%d+)|h")
    if currencyID then
        currencyID = tonumber(currencyID)
        if amount then
            -- Remove comma separators (e.g., "1,000" -> "1000") — mirrors
            -- the gold path below exactly (comma-grouped amounts otherwise
            -- capture only the digits after the last comma: "1,000" -> "000").
            amount = amount:gsub(",", "")
        end
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

-- Split a single line further on embedded field-prefixes (Zone:, Faction:,
-- Cost:, Category:). Some catalog entries pack every field onto one line
-- with plain spaces instead of |n separators (e.g. decorID 714); without
-- this, everything past the source-type prefix collapses into `name`.
-- %f[%a] anchors each prefix to a word start so it can't false-match inside
-- a longer word (a vendor named "...Costanza" won't split on "Cost:" since
-- there's no colon there anyway, but this guards the general case).
local function SplitEmbeddedFields(line, profile)
    if not profile or not profile.fields then return {line} end

    local cuts = {}
    for prefix in pairs(profile.fields) do
        local pattern = "%f[%a]" .. EscapePattern(prefix)
        local searchFrom = 1
        while true do
            local s, e = strfind(line, pattern, searchFrom)
            if not s then break end
            if s > 1 then
                table_insert(cuts, s)
            end
            searchFrom = e + 1
        end
    end

    if #cuts == 0 then return {line} end
    table_sort(cuts)

    local segments = {}
    local segStart = 1
    for _, cutPos in ipairs(cuts) do
        if cutPos > segStart then
            table_insert(segments, Trim(strsub(line, segStart, cutPos - 1)))
            segStart = cutPos
        end
    end
    table_insert(segments, Trim(strsub(line, segStart)))
    return segments
end

-- Parse a typed source block (Tier 2 — enUS/enGB)
-- Maps known prefixes to semantic fields
local function ParseSourceBlock(block, profile)
    if not profile then
        return ParseStructuralBlock(block)
    end

    local source = {}

    -- Split block into lines on |n, then further split each line on any
    -- embedded field prefixes (see SplitEmbeddedFields) so space-separated
    -- shapes don't collapse into the name.
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
            for _, segment in ipairs(SplitEmbeddedFields(line, profile)) do
                if segment ~= "" then
                    table_insert(lines, segment)
                end
            end
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

    -- Strip color codes before parsing (API wraps labels in |cFFFFD200...|r)
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
