--[[
    Homestead - DecorClassifier
    Item classification and requirement scraping for vendor scanning

    Extracted from VendorScanner.lua to reduce file size.
    Pure classification logic — no scan state, no persistence.

    Reusable by VendorScanner and any future module needing decor detection.
]]

local addonName, HA = ...

local DecorClassifier = {}
HA.DecorClassifier = DecorClassifier

-------------------------------------------------------------------------------
-- Requirement Patterns
-------------------------------------------------------------------------------

-- Locale-keyed requirement patterns for tooltip scraping (experimental).
-- Only enUS is populated. Future locales: deDE, frFR, esES, ptBR, ruRU, koKR, zhCN, zhTW
DecorClassifier.RequirementPatterns = {
    enUS = {
        {
            -- "Requires The Undying Army - Honored"
            pattern = "^Requires (.+) %- (.+)$",
            build = function(c) return { type = "reputation", faction = c[1], standing = c[2] } end,
        },
        {
            -- "Requires: Completion of quest 'Example'" or "Requires: Something"
            pattern = "^Requires: (.+)$",
            build = function(c) return { type = "quest", name = c[1] } end,
        },
        {
            -- "Requires Raise an Army (12345)" — achievement with ID
            pattern = "^Requires (.+) %((%d+)%)$",
            build = function(c) return { type = "achievement", name = c[1], id = tonumber(c[2]) } end,
        },
        {
            -- "Requires Level 70"
            pattern = "^Requires Level (%d+)$",
            build = function(c) return { type = "level", level = tonumber(c[1]) } end,
        },
    },
    -- deDE = { ... },
    -- frFR = { ... },
}

-------------------------------------------------------------------------------
-- Hidden Scanning Tooltip
-------------------------------------------------------------------------------

-- Hidden scanning tooltip for requirement scraping and decor detection fallback.
-- Do NOT use GameTooltip — that would interfere with the player's visible tooltips.
-- Named frame required: GameTooltipTemplate provides SetMerchantItem and auto-created
-- font strings (HomesteadScanTooltipTextLeft1..N). Without the template, SetMerchantItem
-- is nil on custom tooltip frames in 12.0+.
local scanTooltip = CreateFrame("GameTooltip", "HomesteadScanTooltip", UIParent, "GameTooltipTemplate")

-------------------------------------------------------------------------------
-- Requirement Scraping
-------------------------------------------------------------------------------

-- Scrape item requirements from hidden tooltip (experimental).
-- Returns: nil (could not check), {} (no requirements), or table of requirements.
function DecorClassifier.ScrapeItemRequirements(slotIndex)
    -- Debug: log every call
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.global
    local locale = GetLocale()
    local enabled = db and (db.enableRequirementScraping ~= false) or false
    if HA.Addon then
        HA.Addon:Debug(string.format("ScrapeRequirements: slot %d, enabled=%s, locale=%s",
            slotIndex, tostring(enabled), tostring(locale)))
    end

    -- Check if scraping is enabled
    if not db or db.enableRequirementScraping == false then
        return nil  -- nil = "could not check" (feature disabled)
    end

    -- Check locale support
    local patterns = DecorClassifier.RequirementPatterns[locale]
    if not patterns then
        if HA.Addon then
            HA.Addon:Debug("ScrapeRequirements: no patterns for locale " .. tostring(locale))
        end
        return nil  -- nil = "could not check" (unsupported locale)
    end

    local ok, requirements = pcall(function()
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTooltip:ClearLines()
        scanTooltip:SetMerchantItem(slotIndex)

        local numLines = scanTooltip:NumLines()
        if HA.Addon then
            HA.Addon:Debug(string.format("ScrapeRequirements: tooltip has %d lines", numLines))
        end
        if numLines == 0 then
            return nil  -- tooltip failed to populate
        end

        local reqs = {}

        for i = 1, numLines do
            local line = _G["HomesteadScanTooltipTextLeft" .. i]
            if line then
                local text = line:GetText()
                local r, g, b = line:GetTextColor()

                -- Red text indicates unmet requirements (r > 0.9, g < 0.2, b < 0.2)
                if text and r and r > 0.9 and g < 0.2 and b < 0.2 then
                    if HA.Addon then
                        HA.Addon:Debug(string.format("ScrapeRequirements: RED line %d: '%s' (%.2f,%.2f,%.2f)",
                            i, text, r, g, b))
                    end
                    local matched = false

                    -- Try each pattern type
                    for _, patternDef in ipairs(patterns) do
                        local captures = { text:match(patternDef.pattern) }
                        if #captures > 0 then
                            local req = patternDef.build(captures)
                            if req then
                                table.insert(reqs, req)
                                matched = true
                                break
                            end
                        end
                    end

                    -- Unrecognized red text — store raw for developer review
                    if not matched then
                        table.insert(reqs, { type = "unknown", text = text })
                    end
                end
            end
        end

        return reqs  -- {} = "checked, found none"; populated = requirements found
    end)

    -- Debug: log result
    local resultStr = "nil"
    if ok and requirements then
        resultStr = (#requirements == 0) and "empty({})" or tostring(#requirements) .. " reqs"
    elseif not ok then
        resultStr = "pcall_error: " .. tostring(requirements)
    end
    if HA.Addon then
        HA.Addon:Debug(string.format("ScrapeRequirements result: %s", resultStr))
    end

    if ok then
        return requirements
    else
        return nil  -- pcall failed — treat as "could not check"
    end
end

-------------------------------------------------------------------------------
-- Decor Detection
-------------------------------------------------------------------------------

-- Check if an item is a housing decor item using the Housing Catalog API,
-- with tooltip fallback for achievement-gated items.
-- Returns: isDecor (boolean), decorInfo (table or nil)
function DecorClassifier.CheckIfDecorItem(itemLink, slotIndex)
    local CHC = _G.C_HousingCatalog
    if not itemLink or not CHC or not CHC.GetCatalogEntryInfoByItem then
        return false, nil
    end

    -- Use the Housing Catalog API to check if this item is decor
    local ok, catalogInfo = pcall(CHC.GetCatalogEntryInfoByItem, itemLink, true)
    if ok and catalogInfo then
        -- Extract item ID from link
        local itemID = GetItemInfoInstant(itemLink)
        return true, {
            itemID = itemID,
            entryID = catalogInfo.entryID,
            name = catalogInfo.name,
            isOwned = catalogInfo.isOwned,
            quantityOwned = catalogInfo.quantityOwned,
        }
    end

    -- Fallback: scan tooltip for "Housing Decor" text.
    -- Some items (e.g. achievement-gated decor) are in the Housing Catalog
    -- but GetCatalogEntryInfoByItem() returns nil for them.
    if slotIndex then
        local tooltipOk, tooltipDetected = pcall(function()
            scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            scanTooltip:ClearLines()
            scanTooltip:SetMerchantItem(slotIndex)
            local numLines = scanTooltip:NumLines()
            for i = 1, numLines do
                local line = _G["HomesteadScanTooltipTextLeft" .. i]
                if line then
                    local text = line:GetText()
                    if text and text == "Housing Decor" then
                        return true
                    end
                end
            end
            return false
        end)
        if tooltipOk and tooltipDetected then
            local itemID = GetItemInfoInstant(itemLink)
            if HA.Addon then
                HA.Addon:Debug(string.format(
                    "CheckIfDecorItem: tooltip fallback detected decor for item %d",
                    itemID or 0))
            end
            return true, {
                itemID = itemID,
                name = nil,
                tooltipFallback = true,
            }
        end
    end

    return false, nil
end
