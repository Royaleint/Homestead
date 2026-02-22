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

-- Search a vendor's items for a matching itemID and return formatted cost.
local function SearchVendorItemsForCost(vendor, itemID)
    if not vendor or not vendor.items then return nil end
    for _, item in ipairs(vendor.items) do
        if HA.VendorData:GetItemID(item) == itemID then
            local cost = HA.VendorData:GetItemCost(item)
            if cost then return FormatCost(cost) end
            break
        end
    end
    return nil
end

-- Get cost for an item from a specific vendor (uses VendorData API, no inline format checks)
local function GetItemCostFromVendor(itemID, npcID)
    if not itemID or not HA.VendorData then return nil end

    -- If npcID provided, check that vendor first (VendorDatabase then EndeavorsData)
    if npcID then
        local vendor = HA.VendorDatabase and HA.VendorDatabase.Vendors and HA.VendorDatabase.Vendors[npcID]
            or HA.EndeavorsData and HA.EndeavorsData.Vendors and HA.EndeavorsData.Vendors[npcID]
        local result = SearchVendorItemsForCost(vendor, itemID)
        if result then return result end
    end

    -- Fallback: use ByItemID index to find vendors that sell this item
    local sources = {
        HA.VendorDatabase and HA.VendorDatabase.ByItemID,
        HA.EndeavorsData and HA.EndeavorsData.ByItemID,
    }
    for _, byItemID in ipairs(sources) do
        if byItemID then
            local npcIDs = byItemID[itemID]
            if npcIDs then
                for _, vendorNpcID in ipairs(npcIDs) do
                    local vendor = HA.VendorDatabase and HA.VendorDatabase.Vendors and HA.VendorDatabase.Vendors[vendorNpcID]
                        or HA.EndeavorsData and HA.EndeavorsData.Vendors and HA.EndeavorsData.Vendors[vendorNpcID]
                    local result = SearchVendorItemsForCost(vendor, itemID)
                    if result then return result end
                end
            end
        end
    end

    -- Fallback: check scanned vendor data
    if HA.VendorData.GetScannedItemCost then
        local scannedCost = HA.VendorData:GetScannedItemCost(itemID, npcID)
        if scannedCost then return FormatCost(scannedCost) end
    end

    return nil
end

-------------------------------------------------------------------------------
-- Source Lookup Functions (Legacy - kept for compatibility)
-------------------------------------------------------------------------------

-- Check if item is from an achievement (via AchievementSources)
local function GetAchievementSourceLegacy(itemID)
    if not HA.AchievementSourcesModule or not HA.AchievementSourcesModule.GetAchievementForItem then
        return nil
    end
    return HA.AchievementSourcesModule:GetAchievementForItem(itemID)
end

-- Check if item is from a vendor
local function GetVendorSource(itemID)
    if not HA.VendorData or not HA.VendorData.GetClosestVendorForItem then
        return nil
    end
    return HA.VendorData:GetClosestVendorForItem(itemID)
end

-------------------------------------------------------------------------------
-- Shared Tooltip Enhancement (adds source info lines)
-------------------------------------------------------------------------------

-- Add requirement lines to tooltip for an item (optionally vendor-scoped)
-- Yellow=requirements, red=unmet, green=met
local function AddRequirementsToTooltip(tooltip, itemID, npcID)
    if not HA.SourceManager or not HA.SourceManager.GetRequirements then return end

    -- Check if requirements display is enabled
    if HA.Addon and HA.Addon.db and HA.Addon.db.profile.tooltip
            and HA.Addon.db.profile.tooltip.showRequirements == false then
        return
    end

    local reqs = HA.SourceManager:GetRequirements(itemID, npcID)
    if not reqs or #reqs == 0 then return end

    for _, req in ipairs(reqs) do
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

    -- Use SourceManager status API so completion logic is centralized.
    local completionColor = nil
    if itemID and HA.SourceManager and HA.SourceManager.GetCompletionStatus then
        local completionStatus = HA.SourceManager:GetCompletionStatus(itemID)
        completionColor = completionStatus and completionStatus.color or nil
    end

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

    -- Determine if any block is an achievement or quest — if so, suppress
    -- AddRequirementsToTooltip since the achievement/quest name already is the requirement.
    local hasAchievementOrQuestBlock = false
    if HA.SourceManager and HA.SourceManager.BuildRequirementDedupSet then
        local dedupSet = HA.SourceManager:BuildRequirementDedupSet(blockTypes)
        hasAchievementOrQuestBlock = dedupSet.achievement == true or dedupSet.quest == true
    else
        for _, btype in ipairs(blockTypes) do
            if btype == "achievement" or btype == "quest" then
                hasAchievementOrQuestBlock = true
                break
            end
        end
    end

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

    for blockIdx, lines in ipairs(blocks) do
        -- Blank separator line between multiple source blocks
        if blockIdx > 1 then
            tooltip:AddLine(" ")
        end

        for i, line in ipairs(lines) do
            -- Split "Label: value" into gold label + white/completion-colored value
            local label, value = line:match("^([^:]+:%s*)(.*)")
            if label and value and value ~= "" then
                -- Apply completion color to the value on the first line of the first block only
                local valueColor = (blockIdx == 1 and i == 1 and completionColor) or "|cFFFFFFFF"
                tooltip:AddLine("  " .. "|cFFFFD700" .. label .. "|r" .. valueColor .. value .. "|r", 1, 1, 1)
            elseif label then
                -- Label-only line
                tooltip:AddLine("  " .. "|cFFFFD700" .. line .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
            else
                -- No colon — plain continuation line (e.g. bare cost value with icon)
                tooltip:AddLine("  " .. line, COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
            end
        end
    end

    -- Show requirements (rep, quest gates, etc.) after all source blocks.
    -- Skip when an achievement/quest block was rendered — the name IS the requirement,
    -- calling this would duplicate it as "Requires: <achievement name>".
    if not hasAchievementOrQuestBlock then
        AddRequirementsToTooltip(tooltip, itemID, vendorNpcID)
    end
end

-- Add source information lines to a tooltip (shared between item and catalog tooltips)
-- Uses SourceManager for comprehensive source lookup
-- Intentional UX: tooltips are informational and always show full source context,
-- independent of any map side-panel source filter setting.
local function AddSourceInfoToTooltip(tooltip, itemID, skipOwnership)
    if not itemID then return false end

    -- Use SourceManager if available for comprehensive source lookup
    if HA.SourceManager and HA.SourceManager.GetSource then
        local source = nil

        -- Prefer "available now" source selection when available.
        if HA.SourceManager.GetBestAvailableSource then
            source = HA.SourceManager:GetBestAvailableSource(itemID)
        end

        -- Backward-compatible fallback: original fixed-priority source.
        if not source then
            source = HA.SourceManager:GetSource(itemID)
        end

        if source then
            local parsedTag = source._isParsed and " |cFFAAAAFF(unverified)|r" or ""

            if source.type == "vendor" then
                -- Vendor source
                local vendorName = source.data.name or "Unknown Vendor"
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

                -- Show cost if available
                if source.data.cost then
                    local costStr = FormatCost(source.data.cost)
                    if costStr then
                        tooltip:AddLine("  Cost: |cFFFFFFFF" .. costStr .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                    end
                else
                    -- Try fallback cost lookup
                    local costStr = GetItemCostFromVendor(itemID, source.data.npcID)
                    if costStr then
                        tooltip:AddLine("  Cost: |cFFFFFFFF" .. costStr .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                    end
                end

                -- Show requirements (vendor-specific when npcID available)
                AddRequirementsToTooltip(tooltip, itemID, source.data.npcID)

                return true

            elseif source.type == "quest" then
                -- Quest source
                local questName = source.data.questName or "Unknown Quest"
                local completion = HA.SourceManager and HA.SourceManager.GetCompletionStatus
                    and HA.SourceManager:GetCompletionStatus(itemID, source.type, source.data)
                local questColor = completion and completion.color or "|cFFFFFFFF"
                local statusSuffix = completion and (completion.color .. completion.suffix .. "|r") or ""
                tooltip:AddLine("Source: Quest" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  " .. questColor .. questName .. "|r" .. statusSuffix, 1, 1, 1)
                -- No AddRequirementsToTooltip: the quest IS the source, would duplicate.
                return true

            elseif source.type == "achievement" then
                -- Achievement source
                local achievementName = source.data.achievementName or "Unknown Achievement"
                local completion = HA.SourceManager and HA.SourceManager.GetCompletionStatus
                    and HA.SourceManager:GetCompletionStatus(itemID, source.type, source.data)
                local nameColor = completion and completion.color or "|cFFFFFFFF"
                local statusSuffix = completion and (completion.color .. completion.suffix .. "|r") or ""

                tooltip:AddLine("Source: Achievement" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  " .. nameColor .. achievementName .. "|r" .. statusSuffix, 1, 1, 1)
                -- No AddRequirementsToTooltip: the achievement IS the source, would duplicate.
                return true

            elseif source.type == "profession" then
                -- Profession source
                local profession = source.data.profession or "Unknown"
                local recipeName = source.data.recipeName or "Unknown Recipe"
                local completion = HA.SourceManager and HA.SourceManager.GetCompletionStatus
                    and HA.SourceManager:GetCompletionStatus(itemID, source.type, source.data)
                local recipeColor = completion and completion.color or "|cFF808080"
                local recipeSuffix = completion and (completion.color .. completion.suffix .. "|r") or "|cFF808080 (Unknown)|r"

                tooltip:AddLine("Source: |cFFFFFFFF" .. profession .. "|r" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  Recipe: " .. recipeColor .. recipeName .. "|r" .. recipeSuffix, 1, 1, 1)
                AddRequirementsToTooltip(tooltip, itemID)
                return true

            elseif source.type == "event" then
                -- Seasonal event vendor source
                local eventName = source.data.event or "Unknown Event"
                local vendorName = source.data.vendorName or "Event Vendor"
                local currency = source.data.currency

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

                tooltip:AddLine("Source: |cFFFFFFFF" .. eventName .. "|r" .. statusText .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  Vendor: |cFFFFFFFF" .. vendorName .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                if source.data.zone then
                    tooltip:AddLine("  Zone: |cFFFFFFFF" .. source.data.zone .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                end
                if currency then
                    tooltip:AddLine("  Currency: |cFFFFFFFF" .. currency .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                end
                AddRequirementsToTooltip(tooltip, itemID)
                return true

            elseif source.type == "drop" then
                -- Drop source
                local mobName = source.data.mobName or "Unknown"
                local zone = source.data.zone or "Unknown Location"
                tooltip:AddLine("Source: Drop" .. parsedTag, COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  |cFFFFFFFF" .. mobName .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                tooltip:AddLine("  Zone: |cFFFFFFFF" .. zone .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                if source.data.notes then
                    tooltip:AddLine("  |cFFFFFFFF" .. source.data.notes .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
                end
                AddRequirementsToTooltip(tooltip, itemID)
                return true
            end
        end
    end

    -- Fallback: Legacy source lookup (AchievementSources + VendorData)
    -- Check for achievement source (AchievementSources)
    local achievementInfo = GetAchievementSourceLegacy(itemID)
    if achievementInfo then
        local achievementName = achievementInfo.name or "Unknown Achievement"
        -- AchievementSources only has a boolean .completed — no wasEarnedByMe available
        -- Re-query GetAchievementInfo if we have an ID for the three-tier check
        local nameColor, statusSuffix = "|cFFFFFFFF", ""
        local achID = achievementInfo.achievementID
        if achID and GetAchievementInfo then
            local id, _, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(achID)
            if id then
                if wasEarnedByMe then
                    nameColor    = "|cFF00FF00"
                    statusSuffix = " |cFF00FF00(This Character)|r"
                elseif completed then
                    nameColor    = "|cFF66FF66"
                    statusSuffix = " |cFF66FF66(Account)|r"
                else
                    nameColor    = "|cFFFF0000"
                    statusSuffix = " |cFFFF0000(Incomplete)|r"
                end
            end
        elseif achievementInfo.completed then
            nameColor    = "|cFF00FF00"
            statusSuffix = " |cFF00FF00(Completed)|r"
        end

        tooltip:AddLine("Source: Achievement", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        tooltip:AddLine("  " .. nameColor .. achievementName .. "|r" .. statusSuffix, 1, 1, 1)

        if achievementInfo.expansion then
            tooltip:AddLine("  Expansion: |cFFFFFFFF" .. achievementInfo.expansion .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

        return true
    end

    -- Check for vendor source (fallback)
    local vendorInfo = GetVendorSource(itemID)
    if vendorInfo then
        local vendorName = vendorInfo.name or "Unknown Vendor"
        local zoneName = vendorInfo.zone or "Unknown Location"
        local locationText = vendorInfo.subzone
            and (vendorInfo.subzone .. " (" .. zoneName .. ")")
            or zoneName

        tooltip:AddLine("Source: |cFFFFFFFF" .. vendorName .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        tooltip:AddLine("  Location: |cFFFFFFFF" .. locationText .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)

        if vendorInfo.faction and vendorInfo.faction ~= "Neutral" then
            local factionColor = vendorInfo.faction == "Alliance" and "|cFF0078FF" or "|cFFFF0000"
            tooltip:AddLine("  Faction: " .. factionColor .. vendorInfo.faction .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

        local costStr = GetItemCostFromVendor(itemID, vendorInfo.npcID)
        if costStr then
            tooltip:AddLine("  Cost: |cFFFFFFFF" .. costStr .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

        if vendorInfo.notes then
            tooltip:AddLine("  |cFFFFFFFF" .. vendorInfo.notes .. "|r", COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b)
        end

        return true
    end

    return false
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
        local hasSource = AddSourceInfoToTooltip(tooltip, itemID)

        if not hasSource then
            tooltip:AddLine("Source: Unknown", COLOR_GRAY.r, COLOR_GRAY.g, COLOR_GRAY.b)
        end
    end

    tooltip:Show()
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
            hasSource = AddSourceInfoToTooltip(tooltip, itemID, true)
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
