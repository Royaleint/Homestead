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

-- Local state
local isHooked = false
local isCatalogHooked = false
local cachedMerchantNpcID = nil  -- Set by MERCHANT_SHOW, cleared by MERCHANT_CLOSED
local lastDebugKey = nil         -- Throttle debug logging (item+context+detailed)

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

-- Check if an item is a housing decor item using the Housing Catalog API
local function IsDecorItem(itemLink)
    if not itemLink then return false end
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then
        return false
    end

    local success, info = pcall(function()
        return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, false)
    end)

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
local function AddRequirementsToTooltip(tooltip, itemID, npcID, dedupSet, reputationOnly)
    if not HA.SourceManager or not HA.SourceManager.GetRequirements then return end

    -- Check if requirements display is enabled
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
            and HA.Addon.db.profile.tooltip.showRequirements == false then
        return
    end

    local reqs = HA.SourceManager:GetRequirements(itemID, npcID)
    if not reqs or #reqs == 0 then return end

    for _, req in ipairs(reqs) do
        -- Filter: reputationOnly skips non-reputation; dedupSet skips already-rendered (except reputation)
        if (not reputationOnly or req.type == "reputation")
                and (not dedupSet or req.type == "reputation" or not dedupSet[req.type]) then
            local text = nil
            local isMet = nil

            if req.type == "reputation" and req.faction and req.standing then
                -- Try enhanced progress display
                local progress = HA.SourceManager.GetRequirementProgress
                    and HA.SourceManager:GetRequirementProgress(req)
                if progress then
                    isMet = progress.met
                    if progress.isRenown then
                        text = progress.factionName .. " \226\128\148 Renown: "
                            .. progress.currentText .. " / " .. progress.requiredText .. " required"
                    else
                        text = progress.factionName .. " \226\128\148 Reputation: "
                            .. progress.currentText .. " / " .. progress.requiredText .. " required"
                    end
                else
                    -- Fallback: flat format when progress unavailable
                    text = "Requires: " .. req.faction .. " - " .. req.standing
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
end

-------------------------------------------------------------------------------
-- sourceText Rendering
-------------------------------------------------------------------------------

-- Render Blizzard's raw sourceText with gold labels and white values.
-- sourceText uses |n line separators and |cFF...label...|r color codes around labels.
-- Currency icon hyperlinks (e.g. |Hcurrency:...|h|h) are preserved as-is so WoW renders them.
-- itemID is used to look up achievement/quest/profession completion status via our indexed DB tables.
-- Defined after AddRequirementsToTooltip to avoid forward reference (Lua 5.1).
local SOURCE_PREFIX_FALLBACK = {
    vendor = true,
    quest = true,
    achievement = true,
    profession = true,
    drop = true,
}

local function NormalizeSourceTypeFromPrefix(prefixKey)
    if not prefixKey then return nil end
    local sourceType = prefixKey:match("^(%a+):")
    if not sourceType then return nil end

    sourceType = sourceType:lower()
    if HA.SourceManager and HA.SourceManager.NormalizeSourceType then
        return HA.SourceManager:NormalizeSourceType(sourceType)
    end

    if SOURCE_PREFIX_FALLBACK[sourceType] then
        return sourceType
    end

    return nil
end

local function RenderSourceText(tooltip, sourceText, itemID)
    if not sourceText or sourceText == "" then return end

    -- Strip color codes and hyperlink wrappers.
    -- |H...|h[text]|h → keep just [text]  (tooltip:AddLine can't render |H hyperlinks)
    -- |c/|r color codes stripped so we can apply our own gold/white scheme.
    -- |n separators are preserved for the split step below.
    local plain = sourceText
        :gsub("|H[^|]*|h([^|]*)|h", "%1")   -- |Htype:id|h[display]|h  → display text
        :gsub("|c%x%x%x%x%x%x%x%x", "")      -- strip |cFFRRGGBB
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
        if not vendorNpcID and HA.VendorDatabase and HA.VendorDatabase.ByItemID then
            local npcList = HA.VendorDatabase.ByItemID[itemID]
            if npcList and npcList[1] then vendorNpcID = npcList[1] end
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

    -- Show requirements after all source blocks using dedupSet.
    -- Achievement/quest types are suppressed if rendered as source blocks,
    -- but reputation and other requirement types always show.
    AddRequirementsToTooltip(tooltip, itemID, vendorNpcID, dedupSet)
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
    local profession = source.data.profession or "Unknown"

    if not detailed then
        tooltip:AddLine("Source: Profession - |cFFFFFFFF" .. profession .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        return
    end

    local recipeName = source.data.recipeName or "Unknown Recipe"
    local recipeColor = completion and completion.color or "|cFF808080"
    local recipeSuffix = completion and (completion.color .. completion.suffix .. "|r") or "|cFF808080 (Unknown)|r"

    tooltip:AddLine("Source: |cFFFFFFFF" .. profession .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
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

-- Dispatch table for per-source-type rendering
local SOURCE_RENDERERS = {
    vendor = RenderVendorSourceLines,
    quest = RenderQuestSourceLines,
    achievement = RenderAchievementSourceLines,
    profession = RenderProfessionSourceLines,
    event = RenderEventSourceLines,
    drop = RenderDropSourceLines,
}

-------------------------------------------------------------------------------
-- Context Detection
-------------------------------------------------------------------------------

-- Detect tooltip context from the tooltip's owner frame.
-- Returns "panel", "merchant", or "standard".
local function DetectContext(tooltip)
    local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner()
    if not owner then return "standard" end

    -- Panel: MapSidePanel stamps this flag on item icon frames (B1)
    if owner.isHomesteadPanelIcon then return "panel" end

    -- Merchant: only if a merchant is open AND the owner is a merchant item button.
    -- Prevents misclassifying bag/AH/chat tooltips while vendor window is open.
    if cachedMerchantNpcID then
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
local function AddSourceInfoToTooltip(tooltip, itemID, context, detailed)
    if not itemID then return false end
    if not HA.SourceManager or not HA.SourceManager.GetAllSources then return false end

    -- Defaults (backward-compatible for catalog handler which passes no context/detailed)
    context = context or "standard"
    if detailed == nil then detailed = true end

    -- Merchant compact: no sources rendered (caller handles reputation-only requirements)
    if context == "merchant" and not detailed then
        return false
    end

    local sources = HA.SourceManager:GetAllSources(itemID)
    if not sources or #sources == 0 then return false end

    -- Determine which sources to render
    local sourcesToRender
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
    if db and db.showAllSources == false then
        -- Show primary only: prefer "available now" source (preserves existing behavior)
        local best = HA.SourceManager.GetBestAvailableSource
            and HA.SourceManager:GetBestAvailableSource(itemID)
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

    -- Render each source via dispatch table, tracking which types were rendered
    local renderedAny = false
    local renderedTypes = {}
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
            and HA.SourceManager:BuildRequirementDedupSet(renderedTypes)
            or nil

        -- In merchant context, Blizzard already shows achievement/quest requirements
        -- on the merchant tooltip — suppress ours to avoid duplication.
        if context == "merchant" then
            dedupSet = dedupSet or {}
            dedupSet["achievement"] = true
            dedupSet["quest"] = true
        end

        -- npcID scoping: pass vendor npcID when vendor is sole rendered source,
        -- or in merchant context (vendor window is open).
        local reqNpcID = nil
        if #renderedTypes == 1 and renderedTypes[1] == "vendor" then
            reqNpcID = renderedVendorNpcID
        elseif context == "merchant" and cachedMerchantNpcID then
            reqNpcID = cachedMerchantNpcID
        end

        AddRequirementsToTooltip(tooltip, itemID, reqNpcID, dedupSet)
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

    -- Check ownership status (always check, but only display if setting enabled)
    local isOwned = IsDecorOwned(itemLink)
    if not db or db.showOwned ~= false then
        if isOwned == true then
            tooltip:AddLine("Status: Owned", COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        elseif isOwned == false then
            tooltip:AddLine("Status: Not Owned", COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        else
            tooltip:AddLine("Status: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    -- Show quantity if owned and setting enabled
    if isOwned and db and db.showQuantity then
        local success, info = pcall(function()
            return C_HousingCatalog.GetCatalogEntryInfoByItem(itemLink, true)
        end)
        if success and info and info.quantity and info.quantity > 0 then
            tooltip:AddLine("Quantity: " .. info.quantity, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end
    end

    -- Add source info (if enabled - default true)
    if not db or db.showSource ~= false then
        if context == "merchant" then
            if not detailed then
                -- Merchant compact: only show reputation requirements (our value-add).
                -- Blizzard already shows cost, vendor name, basic requirements.
                AddRequirementsToTooltip(tooltip, itemID, cachedMerchantNpcID, nil, true)
            else
                -- Merchant detailed: show supplemental sources + all requirements.
                -- No "Source: Unknown" fallback — the vendor IS the source.
                local hasSupplemental = AddSourceInfoToTooltip(tooltip, itemID, context, detailed)
                -- If no supplemental sources rendered, AddSourceInfoToTooltip skipped
                -- requirements internally — show them here with merchant npcID scope.
                -- Suppress achievement/quest requirements (Blizzard shows these).
                if not hasSupplemental then
                    local merchantDedupSet = { achievement = true, quest = true }
                    AddRequirementsToTooltip(tooltip, itemID, cachedMerchantNpcID, merchantDedupSet)
                end
            end
        else
            local hasSource = AddSourceInfoToTooltip(tooltip, itemID, context, detailed)
            if not hasSource then
                tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
            end
        end
    end

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
        -- Some entries store itemID differently
        itemID = entryInfo.entryID.itemID or entryInfo.entryID
    end

    if not itemID then
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

    -- Add source info (ownership is already shown by the catalog UI)
    -- Only show if enabled (default true)
    if not db or db.showSource ~= false then
        local hasSource = false

        -- Priority 1: Blizzard sourceText (authoritative, most complete — includes cost icons,
        -- all vendor/zone/category fields). Rendered with gold labels + white values.
        if entryInfo.sourceText and entryInfo.sourceText ~= "" then
            RenderSourceText(tooltip, entryInfo.sourceText, itemID)
            hasSource = true
            if HA.DevAddon and HA.Addon.db.profile.debug then
                HA.Addon:Debug("Catalog tooltip: using Blizzard sourceText")
            end
        end

        -- Priority 2: Fall back to our structured DB for items with no sourceText
        if not hasSource then
            hasSource = AddSourceInfoToTooltip(tooltip, itemID)
            if hasSource and HA.DevAddon and HA.Addon.db.profile.debug then
                HA.Addon:Debug("Catalog tooltip: using VendorDatabase/AchievementSources")
            end
        end

        -- Priority 3: Show unknown if both failed
        if not hasSource then
            tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

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

local function HookTooltips()
    if isHooked then return end

    -- Use TooltipDataProcessor for modern WoW (10.0.2+)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            -- Only process GameTooltip and similar tooltips
            if tooltip == GameTooltip or tooltip == ItemRefTooltip or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then
                OnTooltipSetItem(tooltip, data)
            end
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

-- Helper to check if addon is loaded (compatible with different WoW versions)
local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

local function Initialize()
    -- Hook standard item tooltips
    HookTooltips()

    -- Track merchant open/close for context detection (used by DetectContext)
    local merchantFrame = CreateFrame("Frame")
    merchantFrame:RegisterEvent("MERCHANT_SHOW")
    merchantFrame:RegisterEvent("MERCHANT_CLOSED")
    merchantFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            local guid = UnitGUID("npc")
            if guid then
                local ok, npcIDText = pcall(string.match, guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
                cachedMerchantNpcID = ok and tonumber(npcIDText) or nil
            else
                cachedMerchantNpcID = nil
            end
        else
            cachedMerchantNpcID = nil
        end
    end)

    -- Try to hook Housing Catalog if already loaded
    if IsAddonLoaded("Blizzard_HousingDashboard") or IsAddonLoaded("Blizzard_HousingTemplates") then
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

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

HA.Tooltips = {
    -- Manual refresh (re-hook if needed)
    Refresh = function()
        if not isHooked then
            HookTooltips()
        end
        if not isCatalogHooked then
            HookHousingCatalog()
        end
    end,

    -- Check if tooltips are hooked
    IsHooked = function()
        return isHooked
    end,

    -- Check if catalog tooltips are hooked
    IsCatalogHooked = function()
        return isCatalogHooked
    end,

    -- Manually add decor info to a tooltip (for custom UI)
    AddDecorInfo = function(tooltip, itemLink)
        AddDecorInfoToTooltip(tooltip, itemLink)
    end,

    -- Add source info only (for external use)
    AddSourceInfo = function(tooltip, itemID)
        return AddSourceInfoToTooltip(tooltip, itemID)
    end,
}
