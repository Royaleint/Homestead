--[[
    Homestead - Tooltip Enhancements
    Add decor collection status and source info to item tooltips

    Supports:
    - Standard item tooltips (bags, merchants, etc.) via TooltipDataProcessor
    - Housing Catalog UI tooltips via EventRegistry "HousingCatalogEntry.TooltipCreated"

    Note: WoW 10.0.2+ uses TooltipDataProcessor instead of OnTooltipSetItem
]]

local _, HA = ...

-- Upvalued Lua stdlib
local ipairs = ipairs
local tonumber = tonumber
local pcall = pcall
local stringMatch = string.match

-- Local state
local isHooked = false
local isCatalogHooked = false
local merchantFrameOpen = false   -- Set by MERCHANT_SHOW, cleared by MERCHANT_CLOSED
local cachedMerchantNpcID = nil   -- Best-effort NPC ID cache for vendor-scoped requirements
local lastDebugKey = nil         -- Throttle debug logging (item+context+detailed)
local lastTooltipFrame = nil     -- Tooltip frame we most recently augmented
local lastTooltipOwner = nil     -- Owner frame of last decor tooltip (for Shift refresh)
local lastShiftState = false     -- Previous Shift key state (anti-thrash)

-- Colors
local COLOR_GREEN = {r = 0, g = 1, b = 0}
local COLOR_RED = {r = 1, g = 0, b = 0}
local COLOR_YELLOW = {r = 1, g = 0.82, b = 0}
local COLOR_WHITE = {r = 1, g = 1, b = 1}
local COLOR_GRAY = {r = 0.5, g = 0.5, b = 0.5}

-------------------------------------------------------------------------------
-- Helper Functions
-------------------------------------------------------------------------------

-- Extract item ID from item link
local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    local itemID = itemLink:match("item:(%d+)")
    return itemID and tonumber(itemID)
end

local function GetNPCIDFromGUID(guid)
    if not guid then return nil end

    -- UnitGUID can be a restricted "secret string" in some merchant contexts
    -- (for example repair mounts/anvils). Guard matching so tooltip setup
    -- degrades to an unscoped merchant context instead of hard-erroring.
    local ok, npcIDText = pcall(stringMatch, guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if not ok then
        return nil
    end

    return npcIDText and tonumber(npcIDText) or nil
end

-- Check if an item is a housing decor item using the Housing Catalog API
local function IsDecorItem(itemLink)
    if not itemLink then return false end
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        return false
    end

    local success, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemLink, false)
    return success and info ~= nil
end

-- Check if a decor item is owned (by itemLink)
-- Delegates to CatalogStore:IsOwnedFresh() (Phase 2)
local function IsDecorOwned(itemLink)
    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return nil end
    if HA.CatalogStore then
        return HA.CatalogStore:IsOwnedFresh(itemID)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Cost Lookup Functions
-------------------------------------------------------------------------------

-- Format cost using VendorData (canonical formatter, always available via TOC load order)
local function FormatCost(cost)
    if HA.VendorData then
        return HA.VendorData:FormatCost(cost)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Shared Tooltip Enhancement (adds source info lines)
-------------------------------------------------------------------------------

-- Add requirement lines to tooltip for an item (optionally vendor-scoped)
-- Yellow=requirements, red=unmet, green=met
-- dedupSet: optional table of source types already rendered (e.g. {achievement=true})
--   requirements whose type is in dedupSet are skipped (already shown as source lines).
--   Reputation requirements are NEVER skipped (always additive info).
-- reputationOnly: if true, only render reputation requirements (merchant compact mode)
-- Returns: set of faction names that had reputation progress rendered (for cross-path dedup),
--   or nil if no reputation progress was rendered.
local function AddRequirementsToTooltip(tooltip, itemID, npcID, dedupSet, reputationOnly)
    if not HA.SourceManager or not HA.SourceManager.GetRequirements then return nil end

    -- Check if requirements display is enabled
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
            and HA.Addon.db.profile.tooltip.showRequirements == false then
        return nil
    end

    local reqs = HA.SourceManager:GetRequirements(itemID, npcID)
    if not reqs or #reqs == 0 then return nil end

    local renderedFactions = nil  -- tracks factions with progress lines (for cross-path dedup)

    for _, req in ipairs(reqs) do
        -- Filter: reputationOnly skips non-reputation; dedupSet skips already-rendered (except reputation).
        -- Dedup checks both broad type keys ("quest") from merchant/sourceText contexts and
        -- specific name keys ("quest:QuestName") from rendered source objects.
        local isDuped = false
        if dedupSet and req.type ~= "reputation" then
            isDuped = dedupSet[req.type]
                or (req.name and dedupSet[req.type .. ":" .. req.name])
        end
        if (not reputationOnly or req.type == "reputation") and not isDuped then
            local text = nil
            local isMet = nil

            if req.type == "reputation" and req.faction and req.standing then
                -- Requirement line: "Requires Renown/Friendship/Reputation: Faction - Standing"
                local friendshipRanks = HA.SourceManager and HA.SourceManager.FRIENDSHIP_RANK_ORDER
                local prefix
                local renownLevel = req.standing:match("^[Rr]enown%s+(%d+)$")
                if renownLevel then
                    prefix = "Requires Renown"
                elseif friendshipRanks and friendshipRanks[req.standing] then
                    prefix = "Requires Friendship"
                else
                    prefix = "Requires Reputation"
                end
                local displayFaction = req.faction:gsub("%.$", "")  -- strip trailing period from SavedVars
                tooltip:AddLine("  " .. prefix .. ": " .. displayFaction .. " - " .. req.standing,
                    COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)

                -- Progress line: "Your renown: X / Y" or "Your standing: X / Y"
                local progress = HA.SourceManager.GetRequirementProgress
                    and HA.SourceManager:GetRequirementProgress(req)
                if progress then
                    isMet = progress.met
                    if progress.isRenown then
                        text = "Your renown: " .. progress.currentText .. " / " .. progress.requiredText
                    else
                        text = "Your standing: " .. progress.currentText .. " / " .. progress.requiredText
                    end
                    -- Track rendered faction for cross-path dedup with AddReputationProgressToTooltip
                    renderedFactions = renderedFactions or {}
                    renderedFactions[displayFaction] = true
                end
            elseif req.type == "quest" and req.name then
                text = "Requires: " .. req.name
            elseif req.type == "achievement" and req.name then
                text = "Requires: " .. req.name
            elseif req.type == "level" and req.level then
                text = "Requires Level " .. req.level
            elseif req.type == "unknown" and req.text then
                text = req.text
            end

            if text then
                if isMet == nil then
                    isMet = HA.SourceManager:IsRequirementMet(req)
                end
                if isMet == true then
                    tooltip:AddLine("  " .. text, 0.0, 0.8, 0.0)  -- Green
                elseif isMet == false then
                    tooltip:AddLine("  " .. text, 0.8, 0.0, 0.0)  -- Red
                else
                    tooltip:AddLine("  " .. text, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)  -- Yellow (unknown)
                end
            end
        end
    end

    return renderedFactions
end

-- Query Blizzard's item tooltip data for reputation/renown requirements.
-- Uses C_TooltipInfo.GetItemByID() to read structured tooltip lines without
-- needing to scan a rendered tooltip frame (works for any tooltip type).
-- Returns a table of parsed requirement objects suitable for GetRequirementProgress().
local function GetItemReputationRequirements(itemID)
    local reqs = {}
    if not itemID then return reqs end
    if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then return reqs end

    local tooltipData = C_TooltipInfo.GetItemByID(itemID)
    if not tooltipData or not tooltipData.lines then return reqs end

    for _, lineData in ipairs(tooltipData.lines) do
        local text = lineData.leftText
        if text then
            -- Renown: "Requires Renown Rank 15 with the Silvermoon Court"
            -- Case-insensitive on "Rank"/"rank" to match both tooltip and catalog text.
            local level, faction = text:match("Requires Renown [Rr]ank (%d+) with the (.+)")
            if not level then
                level, faction = text:match("Requires Renown [Rr]ank (%d+) with (.+)")
            end
            if level and faction then
                faction = faction:gsub("%.$", "")  -- strip trailing period
                reqs[#reqs + 1] = { type = "reputation", faction = faction, standing = "Renown " .. level }
            else
                -- Friendship: "Requires the Socialite rank or above with the Blood Knights of Silvermoon"
                local rank, factionName = text:match("Requires the (.+) rank or above with the (.+)")
                if rank and factionName then
                    reqs[#reqs + 1] = { type = "reputation", faction = factionName, standing = rank }
                end
            end
        end
    end
    return reqs
end

-- Add progress lines for reputation/renown requirements scanned from the tooltip.
-- Shows player's current standing vs required, colored red/green.
-- renderedFactions: optional set of faction names already rendered by AddRequirementsToTooltip
--   (cross-path dedup to prevent duplicate progress lines for the same faction).
local function AddReputationProgressToTooltip(tooltip, itemReqs, renderedFactions)
    if not itemReqs or #itemReqs == 0 then return end
    if not HA.SourceManager or not HA.SourceManager.GetRequirementProgress then return end

    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
            and HA.Addon.db.profile.tooltip.showRequirements == false then
        return
    end

    for _, req in ipairs(itemReqs) do
        -- Skip factions already rendered by AddRequirementsToTooltip
        local factionName = req.faction and req.faction:gsub("%.$", "")
        if not (renderedFactions and factionName and renderedFactions[factionName]) then
            local progress = HA.SourceManager:GetRequirementProgress(req)
            if progress then
                local text
                if progress.isRenown then
                    text = "Your renown: " .. progress.currentText .. " / " .. progress.requiredText
                else
                    text = "Your standing: " .. progress.currentText .. " / " .. progress.requiredText
                end
                if progress.met == true then
                    tooltip:AddLine(text, 0.0, 0.8, 0.0)  -- Green
                elseif progress.met == false then
                    tooltip:AddLine(text, 0.8, 0.0, 0.0)  -- Red
                else
                    tooltip:AddLine(text, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- sourceText Rendering
-------------------------------------------------------------------------------

-- Render Blizzard's raw sourceText with gold labels and white values.
-- sourceText uses |n line separators and |cFF...label...|r color codes around labels.
-- Currency icon hyperlinks (e.g. |Hcurrency:...|h|h) are preserved as-is so WoW renders them.
-- itemID is used to look up achievement/quest/profession completion status via our indexed DB tables.
-- Defined after AddRequirementsToTooltip to avoid forward reference (Lua 5.1).
local function NormalizeSourceTypeFromPrefix(prefixKey)
    if not prefixKey then return nil end
    local sourceType = prefixKey:match("^(%a+):")
    if not sourceType then return nil end

    return HA.SourceManager:NormalizeSourceType(sourceType:lower())
end

local function RenderSourceText(tooltip, sourceText, itemID)
    if not sourceText or sourceText == "" then return end

    -- Strip color codes and hyperlink wrappers.
    -- |H...|h[text]|h → keep just [text]  (tooltip:AddLine can't render |H hyperlinks)
    -- The display capture is non-greedy dot, not [^|]*, because currency links carry
    -- their icon INSIDE the display text (|Hcurrency:ID|h|T...|t|h) and the texture
    -- escape must survive the strip or the raw |H prefix leaks into the tooltip.
    -- |c/|r color codes stripped so we can apply our own gold/white scheme.
    -- |n separators are preserved for the split step below.
    local plain = sourceText
        :gsub("|H[^|]*|h(.-)|h", "%1")      -- |Htype:id|h[display]|h  → display text
        :gsub("|c%x%x%x%x%x%x%x%x", "")      -- strip |cFFRRGGBB
        :gsub("|cn[^:]*:", "")                 -- strip |cnNAMED_COLOR: (WoW 10.x+ named colors)
        :gsub("|r", "")                        -- strip |r

    -- Split all |n lines, then re-group into logical blocks by detecting source-type prefix changes.
    -- Blizzard sometimes separates blocks with |n|n and sometimes runs them together with |n only.
    local allLines = {}
    local pos = 1
    while true do
        local sep = plain:find("|n", pos, true)
        if sep then
            allLines[#allLines + 1] = plain:sub(pos, sep - 1)
            pos = sep + 2
        else
            allLines[#allLines + 1] = plain:sub(pos)
            break
        end
    end

    -- Group lines into blocks: start a new block whenever a source-type prefix is seen
    -- after the very first line, OR when an empty line is encountered (|n|n produces "")
    -- Also track which source types are present so we can suppress duplicate requirements.
    local blocks = {}
    local blockTypes = {}   -- [blockIdx] = "vendor"|"achievement"|"quest"|etc.
    local currentBlock = {}
    local currentType = nil
    for _, line in ipairs(allLines) do
        if line == "" then
            -- Explicit block separator (|n|n)
            if #currentBlock > 0 then
                blocks[#blocks + 1] = currentBlock
                blockTypes[#blocks] = currentType
                currentBlock = {}
                currentType = nil
            end
        else
            local prefix = line:match("^(%a+:%s*)")
            local prefixKey = prefix and prefix:match("^(%a+:)")
            local normalizedType = NormalizeSourceTypeFromPrefix(prefixKey)
            local isSourceType = normalizedType ~= nil
            if isSourceType and #currentBlock > 0 then
                -- New source type encountered mid-block — split here
                blocks[#blocks + 1] = currentBlock
                blockTypes[#blocks] = currentType
                currentBlock = {}
                currentType = nil
            end
            if isSourceType and not currentType then
                -- Record canonical source type for this block.
                currentType = normalizedType
            end
            currentBlock[#currentBlock + 1] = line
        end
    end
    if #currentBlock > 0 then
        blocks[#blocks + 1] = currentBlock
        blockTypes[#blocks] = currentType
    end

    -- Build dedupSet from block types for requirement suppression.
    -- Unlike the old all-or-nothing approach, this only suppresses specific types
    -- (e.g., achievement/quest) while still showing reputation and other requirements.
    local dedupSet = HA.SourceManager and HA.SourceManager.BuildRequirementDedupSet
        and HA.SourceManager:BuildRequirementDedupSet(blockTypes)
        or nil

    -- Resolve a vendor npcID for this item so requirements can be scoped correctly.
    -- Check scanned data first, then static DB index.
    local vendorNpcID = nil
    if itemID then
        if HA.VendorData and HA.VendorData.ScannedByItemID then
            local npcList = HA.VendorData.ScannedByItemID[itemID]
            if npcList and npcList[1] then vendorNpcID = npcList[1] end
        end
        if not vendorNpcID and HA.VendorData and HA.VendorData.GetVendorsForItem then
            local vendors = HA.VendorData:GetVendorsForItem(itemID)
            if vendors and vendors[1] then vendorNpcID = vendors[1].npcID end
        end
    end

    -- Merge separate vendor blocks with the same vendor name.
    -- Blizzard sometimes separates each zone into its own |n|n-delimited block.
    -- This collapses them into a single block before rendering.
    local mergedBlocks = {}
    local mergedBlockTypes = {}
    for blockIdx, lines in ipairs(blocks) do
        local bType = blockTypes[blockIdx]
        local merged = false
        if bType == "vendor" and #mergedBlocks > 0 then
            local prevIdx = #mergedBlocks
            if mergedBlockTypes[prevIdx] == "vendor" then
                -- Compare vendor names (first line of each block)
                local prevName = mergedBlocks[prevIdx][1] and mergedBlocks[prevIdx][1]:match("^Vendor:%s*(.+)")
                local curName = lines[1] and lines[1]:match("^Vendor:%s*(.+)")
                if prevName and curName and prevName == curName then
                    -- Merge: skip the duplicate "Vendor:" header line, append rest
                    for i = 2, #lines do
                        mergedBlocks[prevIdx][#mergedBlocks[prevIdx] + 1] = lines[i]
                    end
                    merged = true
                end
            end
        end
        if not merged then
            mergedBlocks[#mergedBlocks + 1] = lines
            mergedBlockTypes[#mergedBlocks] = bType
        end
    end
    blocks = mergedBlocks
    blockTypes = mergedBlockTypes

    -- Consolidate duplicate "Zone:" lines within vendor blocks.
    -- Blizzard sometimes lists the same vendor with multiple zones (e.g. Mimzy Miscellanea
    -- in Stormwind, Orgrimmar, Dornogal, Silvermoon). Keep only the first zone and append
    -- a count suffix so the tooltip stays compact.
    for blockIdx, lines in ipairs(blocks) do
        if blockTypes[blockIdx] == "vendor" then
            local zoneLines = {}
            for i, line in ipairs(lines) do
                if line:match("^Zone:%s*") then
                    zoneLines[#zoneLines + 1] = i
                end
            end
            if #zoneLines > 1 then
                -- Extract first zone value for the consolidated line
                local firstLabel, firstValue = lines[zoneLines[1]]:match("^([^:]+:%s*)(.*)")
                local extra = #zoneLines - 1
                lines[zoneLines[1]] = (firstLabel or "Zone: ") .. (firstValue or "Unknown")
                    .. " (+" .. extra .. " more location" .. (extra > 1 and "s" or "") .. ")"
                -- Remove remaining zone lines in reverse order to preserve indices
                for j = #zoneLines, 2, -1 do
                    table.remove(lines, zoneLines[j])
                end
            end
        end
    end

    -- Per-block completion lookup via SourceManager
    local hasCompletionAPI = itemID and HA.SourceManager and HA.SourceManager.GetCompletionStatus

    for blockIdx, lines in ipairs(blocks) do
        -- Blank separator line between multiple source blocks
        if blockIdx > 1 then
            tooltip:AddLine(" ")
        end

        -- Resolve per-block completion color + suffix
        local blockCompletion = nil
        if hasCompletionAPI and blockTypes[blockIdx] then
            blockCompletion = HA.SourceManager:GetCompletionStatus(itemID, blockTypes[blockIdx])
        end

        for i, line in ipairs(lines) do
            -- Skip "Faction:" lines — our structured requirement rendering
            -- (AddRequirementsToTooltip) shows this with progress info instead.
            if not line:match("^Faction:%s*") then
                -- Split "Label: value" into gold label + white/completion-colored value
                local label, value = line:match("^([^:]+:%s*)(.*)")
                if label and value and value ~= "" then
                    -- Apply per-block completion color to the first line of each block
                    local valueColor = (i == 1 and blockCompletion and blockCompletion.color) or "|cFFFFFFFF"
                    local valueSuffix = (i == 1 and blockCompletion and blockCompletion.suffix) or ""
                    tooltip:AddLine("  " .. "|cFFFFD700" .. label .. "|r" .. valueColor .. value .. valueSuffix .. "|r", 1, 1, 1)
                elseif label then
                    -- Label-only line
                    tooltip:AddLine("  " .. "|cFFFFD700" .. line .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                else
                    -- No colon — plain continuation line (e.g. bare cost value with icon)
                    tooltip:AddLine("  " .. line, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
                end
            end
        end
    end

    -- Show requirements after all source blocks using dedupSet.
    -- Achievement/quest types are suppressed if rendered as source blocks,
    -- but reputation and other requirement types always show.
    -- Returns renderedFactions set for cross-path dedup with AddReputationProgressToTooltip.
    return AddRequirementsToTooltip(tooltip, itemID, vendorNpcID, dedupSet)
end

-------------------------------------------------------------------------------
-- Per-Source-Type Renderers (extracted from AddSourceInfoToTooltip)
-- Each renderer produces identical tooltip lines to the original inline code.
-------------------------------------------------------------------------------

local function RenderVendorSourceLines(tooltip, source, parsedTag, _itemID, _completion, detailed)
    local vendorName = source.data.name or "Unknown Vendor"

    if not detailed then
        tooltip:AddLine("Source: Vendor - |cFFFFFFFF" .. vendorName .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    local zoneName = source.data.zone or "Unknown Location"
    local locationText = source.data.subzone
        and (source.data.subzone .. " (" .. zoneName .. ")")
        or zoneName

    tooltip:AddLine("Source: |cFFFFFFFF" .. vendorName .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  Location: |cFFFFFFFF" .. locationText .. "|r", COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

    -- Show faction if not neutral
    if source.data.faction and source.data.faction ~= "Neutral" then
        local factionColor = source.data.faction == "Alliance" and "|cFF0078FF" or "|cFFFF0000"
        tooltip:AddLine("  Faction: " .. factionColor .. source.data.faction .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end

    -- Show cost if available (SourceManager includes cost in vendor source data)
    if source.data.cost then
        local costStr = FormatCost(source.data.cost)
        if costStr then
            tooltip:AddLine("  Cost: |cFFFFFFFF" .. costStr .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end
    end
end

local function RenderQuestSourceLines(tooltip, source, parsedTag, _itemID, completion, detailed)
    local questName = source.data.questName or "Unknown Quest"
    local questColor = completion and completion.color or "|cFFFFFFFF"
    local statusSuffix = completion and (completion.color .. completion.suffix .. "|r") or ""

    if not detailed then
        tooltip:AddLine("Source: Quest - " .. questColor .. questName .. "|r" .. statusSuffix .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    tooltip:AddLine("Source: Quest" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  " .. questColor .. questName .. "|r" .. statusSuffix, 1, 1, 1)
end

local function RenderAchievementSourceLines(tooltip, source, parsedTag, _itemID, completion, detailed)
    local achievementName = source.data.achievementName or "Unknown Achievement"
    local nameColor = completion and completion.color or "|cFFFFFFFF"
    local statusSuffix = completion and (completion.color .. completion.suffix .. "|r") or ""

    if not detailed then
        tooltip:AddLine("Source: Achievement - " .. nameColor .. achievementName .. "|r" .. statusSuffix .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    tooltip:AddLine("Source: Achievement" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  " .. nameColor .. achievementName .. "|r" .. statusSuffix, 1, 1, 1)
end

local function RenderProfessionSourceLines(tooltip, source, parsedTag, _itemID, completion, detailed)
    local professionDisplay = source.data.skillTier or source.data.profession or "Unknown"
    if source.data.skillLevel then
        professionDisplay = professionDisplay .. " (" .. source.data.skillLevel .. ")"
    end

    if not detailed then
        tooltip:AddLine("Source: Profession - |cFFFFFFFF" .. professionDisplay .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    local recipeName = source.data.recipeName or "Unknown Recipe"
    local recipeColor = completion and completion.color or "|cFF808080"
    local recipeSuffix = completion and (completion.color .. completion.suffix .. "|r") or "|cFF808080 (Unknown)|r"

    tooltip:AddLine("Source: |cFFFFFFFF" .. professionDisplay .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  Recipe: " .. recipeColor .. recipeName .. "|r" .. recipeSuffix, 1, 1, 1)
end

local function RenderEventSourceLines(tooltip, source, parsedTag, _itemID, _completion, detailed)
    local eventName = source.data.event or "Unknown Event"

    -- Show active/inactive status (omit when unknown/nil)
    local statusText = ""
    if HA.CalendarDetector then
        local isActive = HA.CalendarDetector:IsHolidayActive(eventName)
        if isActive == true then
            statusText = " |cff00ff00(Active Now)|r"
        elseif isActive == false then
            statusText = " |cffff4444(Not Active)|r"
        end
        -- nil = unknown/loading → omit status entirely
    end

    if not detailed then
        tooltip:AddLine("Source: Event - |cFFFFFFFF" .. eventName .. "|r" .. statusText .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    local vendorName = source.data.vendorName or "Event Vendor"
    local currency = source.data.currency

    tooltip:AddLine("Source: |cFFFFFFFF" .. eventName .. "|r" .. statusText .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  Vendor: |cFFFFFFFF" .. vendorName .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    if source.data.zone then
        tooltip:AddLine("  Zone: |cFFFFFFFF" .. source.data.zone .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end
    if currency then
        tooltip:AddLine("  Currency: |cFFFFFFFF" .. currency .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end
end

local function RenderDropSourceLines(tooltip, source, parsedTag, _itemID, _completion, detailed)
    local mobName = source.data.mobName or "Unknown"

    if not detailed then
        tooltip:AddLine("Source: Drop - |cFFFFFFFF" .. mobName .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    local zone = source.data.zone or "Unknown Location"
    tooltip:AddLine("Source: Drop" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  |cFFFFFFFF" .. mobName .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  Zone: |cFFFFFFFF" .. zone .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    if source.data.notes then
        tooltip:AddLine("  |cFFFFFFFF" .. source.data.notes .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end
end

local HEARTHSTEEL_ICON = "|A:hearthsteel-icon-32x32:16:16|a"

local function RenderShopSourceLines(tooltip, source, parsedTag, _itemID, _completion, detailed)
    local data = source.data
    local method = data.method or "hearthsteel"

    local summary
    if method == "hearthsteel" and data.cost then
        summary = data.cost .. " " .. HEARTHSTEEL_ICON
    elseif method == "twitch" then
        summary = "Twitch Drop"
    elseif method == "charity" then
        summary = data.name or "Charity Pack"
    else
        summary = data.name or "Promotion"
    end

    if not detailed then
        tooltip:AddLine("Source: In-Game Shop - |cFFFFFFFF" .. summary .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    tooltip:AddLine("Source: |cFFFFFFFFIn-Game Shop|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    tooltip:AddLine("  Zone: |cFFFFFFFFN/A|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    if method == "hearthsteel" and data.cost then
        tooltip:AddLine("  Cost: |cFFFFFFFF" .. data.cost .. " " .. HEARTHSTEEL_ICON .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end
    if data.name then
        tooltip:AddLine("  Pack: |cFFFFFFFF" .. data.name .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end
    if data.expires then
        tooltip:AddLine("  Available until: |cFFFFFFFF" .. data.expires .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
    end
end

-- Dispatch table for per-source-type rendering
local SOURCE_RENDERERS = {
    vendor = RenderVendorSourceLines,
    quest = RenderQuestSourceLines,
    achievement = RenderAchievementSourceLines,
    profession = RenderProfessionSourceLines,
    event = RenderEventSourceLines,
    shop = RenderShopSourceLines,
    drop = RenderDropSourceLines,
}

-------------------------------------------------------------------------------
-- Context Detection
-------------------------------------------------------------------------------

-- Detect tooltip context from the tooltip's owner frame.
-- Returns "panel", "merchant", or "standard".
local function DetectContext(tooltip)
    if tooltip and tooltip.isHomesteadPanelTooltip then
        return "panel"
    end

    local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner()
    if not owner then return "standard" end

    -- Panel: MapSidePanel stamps this flag on item icon frames (B1)
    if owner.isHomesteadPanelIcon then return "panel" end

    -- Merchant: only if a merchant is open AND the owner is a merchant item button.
    -- Prevents misclassifying bag/AH/chat tooltips while vendor window is open.
    if merchantFrameOpen then
        local ownerName = owner.GetName and owner:GetName()
        if ownerName and ownerName:match("^MerchantItem%d+ItemButton$") then
            return "merchant"
        end
    end

    return "standard"
end

-- Add source information lines to a tooltip (shared between item and catalog tooltips)
-- Uses SourceManager:GetAllSources for comprehensive multi-source display.
-- context: "standard", "merchant", or "panel" (default "standard")
-- detailed: true for full sub-lines + requirements, false for compact one-liners (default true)
-- Intentional UX: tooltips are informational and always show full source context,
-- independent of any map side-panel source filter setting.
local function AddSourceInfoToTooltip(tooltip, itemID, context, detailed, presentation)
    if not itemID then return false end
    if not HA.SourceManager or (not presentation and not HA.SourceManager.GetAllSources) then return false end

    -- Defaults (backward-compatible for catalog handler which passes no context/detailed)
    context = context or "standard"
    if detailed == nil then detailed = true end

    -- Merchant compact: no sources rendered (caller handles reputation-only requirements)
    if context == "merchant" and not detailed then
        return false
    end

    local sources = presentation and presentation.allSources or HA.SourceManager:GetAllSources(itemID)
    if not sources or #sources == 0 then return false end

    -- Determine which sources to render
    local sourcesToRender
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if db and db.showAllSources == false then
        -- Show primary only: prefer "available now" source (preserves existing behavior)
        local best = presentation and presentation.bestSource
            or (HA.SourceManager.GetBestAvailableSource
                and HA.SourceManager:GetBestAvailableSource(itemID))
        sourcesToRender = best and {best} or {sources[1]}
    else
        sourcesToRender = sources
    end

    -- Merchant detailed: skip vendor/achievement/quest sources — Blizzard's merchant
    -- tooltip already shows the vendor, cost, and achievement/quest requirements.
    -- Only show supplemental sources (profession, event, drop) that add new info.
    if context == "merchant" and detailed then
        local filtered = {}
        for _, source in ipairs(sourcesToRender) do
            if source.type ~= "vendor" and source.type ~= "achievement" and source.type ~= "quest" then
                filtered[#filtered + 1] = source
            end
        end
        sourcesToRender = filtered
    end

    -- Consolidate same-name vendor sources: when parsed sourceText yields
    -- multiple vendor entries for the same NPC in different zones, keep only
    -- the first occurrence so the tooltip stays compact.
    if #sourcesToRender > 1 then
        local seenVendors = {}
        local consolidated = {}
        for _, source in ipairs(sourcesToRender) do
            if source.type == "vendor" and source.data and source.data.name then
                if not seenVendors[source.data.name] then
                    seenVendors[source.data.name] = true
                    consolidated[#consolidated + 1] = source
                end
            else
                consolidated[#consolidated + 1] = source
            end
        end
        sourcesToRender = consolidated
    end

    -- Render each source via dispatch table, tracking which types/sources were rendered
    local renderedAny = false
    local renderedTypes = {}
    local renderedSources = {}
    local renderedVendorNpcID = nil
    for _, source in ipairs(sourcesToRender) do
        local renderer = SOURCE_RENDERERS[source.type]
        if renderer then
            local parsedTag = source._isParsed and " |cFFAAAAFF(unverified)|r" or ""
            local completion = HA.SourceManager.GetCompletionStatus
                and HA.SourceManager:GetCompletionStatus(itemID, source.type, source.data)
                or nil
            renderer(tooltip, source, parsedTag, itemID, completion, detailed)
            renderedAny = true
            renderedTypes[#renderedTypes + 1] = source.type
            renderedSources[#renderedSources + 1] = source
            if source.type == "vendor" and source.data then
                renderedVendorNpcID = source.data.npcID
            end
        end
    end

    if not renderedAny then return false end

    -- Requirements gating by context x mode:
    -- Standard compact: no requirements (keep tooltip clean)
    -- Detailed (any context) or panel: show requirements with dedupSet
    if detailed then
        local dedupSet = HA.SourceManager.BuildRequirementDedupSet
            and HA.SourceManager:BuildRequirementDedupSet(renderedTypes, renderedSources)
            or nil

        -- In merchant context, Blizzard already shows achievement/quest/unknown
        -- requirements on the merchant tooltip — suppress ours to avoid duplication.
        if context == "merchant" then
            dedupSet = dedupSet or {}
            dedupSet["achievement"] = true
            dedupSet["quest"] = true
            dedupSet["unknown"] = true
        end

        -- npcID scoping: pass vendor npcID when vendor is sole rendered source,
        -- or in merchant context (vendor window is open).
        local reqNpcID = nil
        if #renderedTypes == 1 and renderedTypes[1] == "vendor" then
            reqNpcID = renderedVendorNpcID
        elseif context == "merchant" and cachedMerchantNpcID then
            reqNpcID = cachedMerchantNpcID
        end

        local reqRenderedFactions = AddRequirementsToTooltip(tooltip, itemID, reqNpcID, dedupSet)
        return true, reqRenderedFactions
    end

    return true
end

-------------------------------------------------------------------------------
-- Standard Item Tooltip Enhancement (bags, merchants, etc.)
-------------------------------------------------------------------------------

local function AddDecorInfoToTooltip(tooltip, itemLink)
    if not itemLink then return end

    -- Check if tooltip additions are enabled
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if db and not db.enabled then return end

    -- Check if this is a decor item
    if not IsDecorItem(itemLink) then
        return
    end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    -- Detect context and detail level
    local context = DetectContext(tooltip)
    local detailed = (context == "panel") or IsShiftKeyDown()

    -- Track owner for Shift-to-refresh (B6)
    lastTooltipFrame = tooltip
    lastTooltipOwner = tooltip:GetOwner()

    -- Debug logging (dev mode only, throttled to avoid spam on repeated tooltip updates)
    if HA.DevAddon and HA.Addon.db.profile.debug then
        local debugKey = itemID .. context .. tostring(detailed)
        if debugKey ~= lastDebugKey then
            lastDebugKey = debugKey
            HA.Addon:Debug(string.format("Tooltip: item=%d context=%s detailed=%s",
                itemID, context, tostring(detailed)))
        end
    end

    -- Add blank line separator
    tooltip:AddLine(" ")

    -- Add header
    tooltip:AddLine("|cFFFFD700[Homestead]|r")

    -- Resolve vendor NPC scope for availability classification
    local vendorNpcID = nil
    if context == "merchant" then
        vendorNpcID = cachedMerchantNpcID
    elseif context == "panel" and lastTooltipOwner and lastTooltipOwner.npcID then
        vendorNpcID = lastTooltipOwner.npcID
    end

    local presentation = nil
    if HA.SourceManager and HA.SourceManager.GetItemPresentation then
        presentation = HA.SourceManager:GetItemPresentation(itemID, {
            context = context,
            npcID = vendorNpcID,
        })
    end

    local isOwned = presentation and presentation.isOwned
    if not presentation then
        isOwned = IsDecorOwned(itemLink)
    end

    local availabilityState = detailed and presentation and presentation.availabilityState or nil
    if detailed and not presentation and HA.SourceManager and HA.SourceManager.GetItemAvailabilityState then
        availabilityState = HA.SourceManager:GetItemAvailabilityState(itemID, vendorNpcID)
    end

    if not db or db.showOwned ~= false then
        if availabilityState == "owned" or isOwned == true then
            tooltip:AddLine("Status: Owned", COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        elseif vendorNpcID and availabilityState == "purchasable" then
            tooltip:AddLine("Status: Available", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        elseif vendorNpcID and availabilityState == "locked" then
            tooltip:AddLine("Status: Locked", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        elseif availabilityState == "available" then
            tooltip:AddLine("Status: Available Now", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        elseif availabilityState == "blocked" then
            tooltip:AddLine("Status: Blocked", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        elseif isOwned == false then
            tooltip:AddLine("Status: Not Owned", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        else
            tooltip:AddLine("Status: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    -- Panel-only opposite-faction vendor access note
    if context == "panel" and vendorNpcID then
        local scopedVendor = HA.VendorData and HA.VendorData.GetVendor
            and HA.VendorData:GetVendor(vendorNpcID)
        if scopedVendor and HA.VendorFilter and HA.VendorFilter.IsOppositeFaction
                and HA.VendorFilter.IsOppositeFaction(scopedVendor)
                and HA.VendorFilter.CanAccessVendor
                and not HA.VendorFilter.CanAccessVendor(scopedVendor) then
            tooltip:AddLine("Vendor access: Opposite-faction vendor on this character", 1.0, 0.5, 0.5)
        end
    end


    -- Query item's reputation/renown requirements from Blizzard's tooltip data.
    -- Blizzard renders these natively above our section; we add progress lines below.
    local itemReqs = GetItemReputationRequirements(itemID)

    -- Add source info (if enabled - default true)
    -- renderedFactions tracks which factions already have progress lines from
    -- AddRequirementsToTooltip, so AddReputationProgressToTooltip can skip them.
    local renderedFactions = nil
    if not db or db.showSource ~= false then
        if context == "merchant" then
            if not detailed then
                -- Merchant compact: only show reputation requirements (our value-add).
                -- Blizzard already shows cost, vendor name, basic requirements.
                renderedFactions = AddRequirementsToTooltip(tooltip, itemID, cachedMerchantNpcID, nil, true)
            else
                -- Merchant detailed: show supplemental sources + all requirements.
                -- No "Source: Unknown" fallback — the vendor IS the source.
                local hasSupplemental
                hasSupplemental, renderedFactions = AddSourceInfoToTooltip(
                    tooltip, itemID, context, detailed, presentation)
                -- If no supplemental sources rendered, AddSourceInfoToTooltip skipped
                -- requirements internally — show them here with merchant npcID scope.
                -- Suppress achievement/quest/unknown requirements (Blizzard shows these).
                if not hasSupplemental then
                    local merchantDedupSet = { achievement = true, quest = true, unknown = true }
                    renderedFactions = AddRequirementsToTooltip(tooltip, itemID, cachedMerchantNpcID, merchantDedupSet)
                end
            end
        else
            local hasSource
            hasSource, renderedFactions = AddSourceInfoToTooltip(
                tooltip, itemID, context, detailed, presentation)
            if not hasSource then
                tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
            end
        end
    end

    -- Add reputation/renown progress from Blizzard's native requirement lines
    AddReputationProgressToTooltip(tooltip, itemReqs, renderedFactions)

    -- Show Shift hint in compact mode when detailed would reveal more content
    if not detailed and context ~= "panel" then
        local showHint = false
        if context == "standard" then
            -- Standard: detailed always adds sub-lines to sources + requirements
            showHint = true
        elseif context == "merchant" and HA.SourceManager then
            -- Merchant: only show hint if detailed would add supplemental sources
            -- or non-reputation/non-achievement/non-quest requirements
            if HA.SourceManager.GetAllSources then
                local allSources = HA.SourceManager:GetAllSources(itemID)
                for _, s in ipairs(allSources) do
                    if s.type ~= "vendor" and s.type ~= "achievement" and s.type ~= "quest" then
                        showHint = true
                        break
                    end
                end
            end
            if not showHint and HA.SourceManager.GetRequirements then
                local reqs = HA.SourceManager:GetRequirements(itemID, cachedMerchantNpcID)
                if reqs then
                    for _, req in ipairs(reqs) do
                        if req.type ~= "reputation" then
                            showHint = true
                            break
                        end
                    end
                end
            end
        end
        if showHint then
            tooltip:AddLine("Hold Shift for details", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end
end

-------------------------------------------------------------------------------
-- Housing Catalog Tooltip Enhancement
-------------------------------------------------------------------------------

-- Handle Housing Catalog tooltips via EventRegistry
-- The catalog fires "HousingCatalogEntry.TooltipCreated" with (entryFrame, tooltip)
-- Note: EventRegistry callbacks receive (ownerID, ...) where ... are the TriggerEvent args
local function OnHousingCatalogTooltipCreated(ownerID, entryFrame, tooltip)
    -- Debug logging (verbose, dev only)
    if HA.DevAddon and HA.Addon.db.profile.debug then
        HA.Addon:Debug("Catalog tooltip callback fired")
    end

    if not entryFrame or not tooltip then
        if HA.DevAddon and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Catalog tooltip: missing entryFrame or tooltip")
        end
        return
    end

    -- Check if tooltip additions are enabled
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if db and not db.enabled then return end

    -- Get entry info from the catalog entry frame
    local entryInfo = entryFrame.entryInfo
    if not entryInfo then
        if HA.DevAddon and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Catalog tooltip: no entryInfo on frame")
        end
        return
    end

    -- Get item ID from entry info (may be itemID or nested in entryID)
    local itemID = entryInfo.itemID
    if not itemID and entryInfo.entryID then
        if type(entryInfo.entryID) == "number" then
            itemID = entryInfo.entryID
        elseif type(entryInfo.entryID) == "table" then
            itemID = entryInfo.entryID.itemID
        end
    end

    if type(itemID) ~= "number" then
        if HA.DevAddon and HA.Addon.db.profile.debug then
            HA.Addon:Debug("Catalog tooltip: no itemID found in entryInfo")
        end
        return
    end

    if HA.DevAddon and HA.Addon.db.profile.debug then
        HA.Addon:Debug("Catalog tooltip: processing itemID", itemID)
    end

    -- Add blank line separator
    tooltip:AddLine(" ")

    -- Add header
    tooltip:AddLine("|cFFFFD700[Homestead]|r")

    -- Query item's reputation/renown requirements from Blizzard's tooltip data
    local itemReqs = GetItemReputationRequirements(itemID)

    -- Add source info (ownership is already shown by the catalog UI)
    -- Only show if enabled (default true)
    -- renderedFactions tracks which factions already have progress lines (cross-path dedup).
    local renderedFactions = nil
    if not db or db.showSource ~= false then
        local hasSource = false

        -- Priority 1: Blizzard sourceText (authoritative, most complete — includes cost icons,
        -- all vendor/zone/category fields). Rendered with gold labels + white values.
        -- Always shown when present, regardless of showAllSources toggle — this is Blizzard's
        -- own catalog data and is intentionally not governed by the user's source filter.
        if entryInfo.sourceText and entryInfo.sourceText ~= "" then
            renderedFactions = RenderSourceText(tooltip, entryInfo.sourceText, itemID)
            hasSource = true
            if HA.DevAddon and HA.Addon.db.profile.debug then
                HA.Addon:Debug("Catalog tooltip: using Blizzard sourceText")
            end
        end

        -- Priority 2: Fall back to our structured DB for items with no sourceText
        if not hasSource then
            local rf
            hasSource, rf = AddSourceInfoToTooltip(tooltip, itemID)
            renderedFactions = renderedFactions or rf
            if hasSource and HA.DevAddon and HA.Addon.db.profile.debug then
                HA.Addon:Debug("Catalog tooltip: using VendorDatabase/AchievementSources")
            end
        end

        -- Priority 3: Show unknown if both failed
        if not hasSource then
            tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    -- Add reputation/renown progress from Blizzard's native requirement lines
    AddReputationProgressToTooltip(tooltip, itemReqs, renderedFactions)

    -- Refresh tooltip to show new lines
    tooltip:Show()
end

-------------------------------------------------------------------------------
-- Tooltip Hooking (Modern API - TooltipDataProcessor)
-------------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip, data)
    if not data then return end

    -- Get item link from tooltip data
    local itemLink
    if data.guid then
        itemLink = C_Item.GetItemLinkByGUID(data.guid)
    elseif data.id then
        -- Try to get full item link
        local _, link = C_Item.GetItemInfo(data.id)
        itemLink = link or ("item:" .. data.id)
    end

    if itemLink then
        AddDecorInfoToTooltip(tooltip, itemLink)
    end
end

-- Issue #38: a tooltip owned by a Blizzard MapCanvas pin (AreaPOI / event-POI /
-- quest-offer / quest pins) must never be touched from our post-call. Doing so
-- runs Homestead (insecure) code inside Blizzard's secure map-data-provider flow
-- and taints it; the next time Blizzard touches a "secret" value in that flow
-- (UI-widget bar width arithmetic, ResizeLayoutMixin anchor-count compare,
-- SetPassThroughButtons) it errors or gets blocked. MapCanvas pins are the only
-- frames that expose a :GetMap() method (MapCanvasPinMixin); Homestead's own
-- world-map pins are plain CreateFrame frames with no such method, so this stays
-- narrowly targeted and changes nothing for any tooltip Homestead legitimately
-- decorates (bags, banks, merchants, the side panel, our own pins).
local function IsBlizzardMapPinOwnedTooltip(tooltip)
    local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner()
    return owner ~= nil and type(owner.GetMap) == "function"
end

local function HookTooltips()
    if isHooked then return end

    -- Use TooltipDataProcessor for modern WoW (10.0.2+)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            -- Only process Blizzard's shared item tooltips plus explicit Homestead-managed ones.
            if not (tooltip == GameTooltip
                    or tooltip == ItemRefTooltip
                    or tooltip == ShoppingTooltip1
                    or tooltip == ShoppingTooltip2
                    or (tooltip and tooltip.isHomesteadManagedTooltip)) then
                return
            end
            -- Issue #38: never augment a Blizzard map-pin tooltip (taint vector).
            if IsBlizzardMapPinOwnedTooltip(tooltip) then
                return
            end
            OnTooltipSetItem(tooltip, data)
        end)

        isHooked = true
        if HA.Addon then
            HA.Addon:Debug("Tooltips hooked via TooltipDataProcessor")
        end
        return
    end

    -- No legacy fallback: TooltipDataProcessor is the supported path.
end

-------------------------------------------------------------------------------
-- Housing Catalog Hook via EventRegistry
-------------------------------------------------------------------------------

local function HookHousingCatalog()
    if isCatalogHooked then return end

    -- EventRegistry is the modern way to hook into Blizzard UI events
    if EventRegistry and EventRegistry.RegisterCallback then
        local success, err = pcall(function()
            EventRegistry:RegisterCallback("HousingCatalogEntry.TooltipCreated", OnHousingCatalogTooltipCreated, HA)
        end)

        if success then
            isCatalogHooked = true
            if HA.Addon then
                HA.Addon:Debug("Housing Catalog tooltips hooked via EventRegistry")
            end
        else
            if HA.Addon then
                HA.Addon:Debug("Failed to hook Housing Catalog tooltips:", err)
            end
        end
    else
        if HA.Addon then
            HA.Addon:Debug("EventRegistry not available for Housing Catalog hook")
        end
    end
end

-- Hook when Blizzard_HousingDashboard addon loads (it may load on-demand)
local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName == "Blizzard_HousingDashboard" or loadedAddonName == "Blizzard_HousingTemplates" then
        if HA.Addon then
            HA.Addon:Debug("Housing addon loaded:", loadedAddonName)
        end
        HookHousingCatalog()
    end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function Initialize()
    -- Hook standard item tooltips
    HookTooltips()

    -- Track merchant open/close for context detection (used by DetectContext)
    local merchantFrame = CreateFrame("Frame")
    merchantFrame:RegisterEvent("MERCHANT_SHOW")
    merchantFrame:RegisterEvent("MERCHANT_CLOSED")
    merchantFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            merchantFrameOpen = true
            cachedMerchantNpcID = GetNPCIDFromGUID(UnitGUID("npc"))
        else
            merchantFrameOpen = false
            cachedMerchantNpcID = nil
        end
    end)

    -- Shift-to-refresh: re-fire OnEnter when Shift toggles detail level (B6)
    local modifierFrame = CreateFrame("Frame")
    modifierFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifierFrame:SetScript("OnEvent", function(_, _, key, state)
        -- Guard 1: only Shift keys
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        -- Guard 2: no actual state change (anti-thrash)
        local isDown = (state == 1)
        if isDown == lastShiftState then return end
        lastShiftState = isDown
        -- Guard 3: tooltip not visible
        if not lastTooltipFrame or not lastTooltipFrame:IsShown() then return end
        -- Guard 4: no tracked owner
        if not lastTooltipOwner then return end
        -- Guard 5: owner changed since we last rendered
        local currentOwner = lastTooltipFrame:GetOwner()
        if currentOwner ~= lastTooltipOwner then
            lastTooltipFrame = nil
            lastTooltipOwner = nil
            return
        end
        -- Re-fire OnEnter to rebuild tooltip with new detail level
        local onEnter = lastTooltipOwner.GetScript and lastTooltipOwner:GetScript("OnEnter")
        if onEnter then
            onEnter(lastTooltipOwner)
        end
    end)

    -- Try to hook Housing Catalog if already loaded
    if C_AddOns.IsAddOnLoaded("Blizzard_HousingDashboard") or C_AddOns.IsAddOnLoaded("Blizzard_HousingTemplates") then
        if HA.Addon then
            HA.Addon:Debug("Housing addon already loaded, hooking now")
        end
        HookHousingCatalog()
    end

    -- Register for addon load events to hook Housing Catalog when it loads.
    -- Skip entirely if already hooked during initialization.
    if not isCatalogHooked then
        local addonFrame = CreateFrame("Frame")
        addonFrame:RegisterEvent("ADDON_LOADED")
        addonFrame:SetScript("OnEvent", function(self, event, loadedAddon)
            OnAddonLoaded(loadedAddon)
            if isCatalogHooked then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end

    if HA.Addon then
        HA.Addon:Debug("Tooltip enhancement module initialized")
    end
end

-- Initialize when addon loads
if HA.Addon then
    C_Timer.After(0, Initialize)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function()
        Initialize()
        initFrame:UnregisterAllEvents()
    end)
end

