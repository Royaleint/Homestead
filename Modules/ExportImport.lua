--[[
    Homestead - Export Module
    Allows users to export scanned vendor data for community sharing
]]

local _, HA = ...

local ExportImport = {}
HA.ExportImport = ExportImport

local L = HA.L or {}

local EXPORT_PREFIX = "HOMESTEAD_EXPORT:"

local function EnableSafeEscapeClose(frame)
    if not frame then return end

    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:HookScript("OnShow", function(self)
        self:SetPropagateKeyboardInput(true)
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
end

-------------------------------------------------------------------------------
-- Export Dialog
-------------------------------------------------------------------------------

local exportDialogFrame = nil

local function CreateExportDialog()
    if exportDialogFrame then return exportDialogFrame end

    local f = CreateFrame("Frame", "HomesteadExportDialog", UIParent, "BackdropTemplate")
    f:SetSize(280, 130)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    EnableSafeEscapeClose(f)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText(L["Export Vendor Data"] or "Export Vendor Data")

    -- Description
    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -8)
    desc:SetWidth(250)
    desc:SetText(L["Choose export option:"] or "Choose export option:")

    -- New Scans export button
    local newBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    newBtn:SetSize(200, 26)
    newBtn:SetPoint("TOP", desc, "BOTTOM", 0, -12)
    newBtn:SetText(L["Export New Scans"] or "Export New Scans")
    newBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendors(false, false)
    end)

    -- Tooltip for new scans button
    newBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Export New Scans", 1, 1, 1)
        GameTooltip:AddLine("Exports all vendors scanned since last export.", 1, 0.82, 0, true)
        GameTooltip:AddLine("Includes vendors already in database for verification.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    newBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Export All button
    local allBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    allBtn:SetSize(200, 26)
    allBtn:SetPoint("TOP", newBtn, "BOTTOM", 0, -6)
    allBtn:SetText(L["Export All"] or "Export All")
    allBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendors(true, true)
    end)

    -- Tooltip for export all button
    allBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Export All", 1, 1, 1)
        GameTooltip:AddLine("Exports ALL scanned vendors, bypassing", 1, 0.82, 0, true)
        GameTooltip:AddLine("the timestamp filter.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    allBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Close button (X)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -3, -3)

    exportDialogFrame = f
    return f
end

function ExportImport:ShowExportDialog()
    local f = CreateExportDialog()
    f:Show()
end

-------------------------------------------------------------------------------
-- Export Functions
-------------------------------------------------------------------------------

-- Format cost data as "c3008:100,i12345:5,nHonor:500" string
-- c = currency (by ID), i = item cost, n = currency (by name, no ID available)
local function FormatCostData(currencies, itemCosts)
    local parts = {}

    -- Add currencies with 'c' prefix (ID known) or 'n' prefix (name only)
    if currencies then
        for _, c in ipairs(currencies) do
            if c.currencyID and c.amount then
                table.insert(parts, "c" .. c.currencyID .. ":" .. c.amount)
            elseif c.name and c.amount then
                -- Escape commas and colons in name to avoid breaking the format
                local escapedName = c.name:gsub(",", "%%2C"):gsub(":", "%%3A")
                table.insert(parts, "n" .. escapedName .. ":" .. c.amount)
            end
        end
    end

    -- Add item costs with 'i' prefix
    if itemCosts then
        for _, ic in ipairs(itemCosts) do
            if ic.itemID and ic.amount then
                table.insert(parts, "i" .. ic.itemID .. ":" .. ic.amount)
            end
        end
    end

    return table.concat(parts, ",")
end

-- Sanitize string fields for tab-delimited export
-- Replaces tabs, newlines, carriage returns with spaces (lossy but safe)
local function SanitizeExportField(value)
    if type(value) ~= "string" then return value or "" end
    return value:gsub("[\t\n\r]", " ")
end

-- Escape delimiters in requirement values for safe serialization
-- Commas → %2C, semicolons → %3B, percent → %25 (must escape first)
local function EscapeReqValue(str)
    if not str then return "" end
    str = str:gsub("%%", "%%25")
    str = str:gsub(",", "%%2C")
    str = str:gsub(";", "%%3B")
    return str
end

-- Format requirements table for export
-- nil → "", {} → "R:none", populated → "R:type,key=val;type,key=val"
local function FormatRequirements(requirements)
    if requirements == nil then return "" end
    if type(requirements) == "table" and #requirements == 0 then return "R:none" end

    local entries = {}
    for _, req in ipairs(requirements) do
        local parts = { EscapeReqValue(req.type or "unknown") }
        if req.faction then table.insert(parts, "faction=" .. EscapeReqValue(SanitizeExportField(req.faction))) end
        if req.standing then table.insert(parts, "standing=" .. EscapeReqValue(SanitizeExportField(req.standing))) end
        if req.name then table.insert(parts, "name=" .. EscapeReqValue(SanitizeExportField(req.name))) end
        if req.id then table.insert(parts, "id=" .. tostring(req.id)) end
        if req.level then table.insert(parts, "level=" .. tostring(req.level)) end
        if req.text then table.insert(parts, "text=" .. EscapeReqValue(SanitizeExportField(req.text))) end
        table.insert(entries, table.concat(parts, ","))
    end
    return "R:" .. table.concat(entries, ";")
end

-- Build primary-source counts for a set of itemIDs.
-- Returns table with canonical source buckets plus unknown.
local function GetPrimarySourceCounts(itemSet)
    local counts = {
        vendor = 0,
        quest = 0,
        achievement = 0,
        profession = 0,
        event = 0,
        drop = 0,
        unknown = 0,
    }

    local SM = HA.SourceManager
    if SM and SM.CountItemsBySourceType then
        return SM:CountItemsBySourceType(itemSet, "primary")
    end

    -- Fallback for older SourceManager versions.
    for itemID in pairs(itemSet) do
        local sourceType = nil
        if SM and SM.GetPrimarySourceType then
            sourceType = SM:GetPrimarySourceType(itemID)
        end
        if not sourceType and SM and SM.GetSource then
            local source = SM:GetSource(itemID)
            sourceType = source and source.type or nil
        end

        if sourceType == "craft" then
            sourceType = "profession"
        end

        if sourceType and counts[sourceType] ~= nil then
            counts[sourceType] = counts[sourceType] + 1
        else
            counts.unknown = counts.unknown + 1
        end
    end

    return counts
end

local function IsDelistCandidate(vendor, npcID)
    if not vendor or not HA.VendorData or not HA.VendorData.HasVendor or not HA.VendorData:HasVendor(npcID) then
        return false
    end

    -- HS-250: ask whether the last scan found any HOUSING item, not whether it
    -- found decor. A vendor selling only room plans, dyes or customizations
    -- scans successfully and captures items, but lastScanHadDecor is false for
    -- it — correctly, since it sells no decor. Reading that as "this vendor had
    -- nothing" emitted a delist row and suppressed every item row below, so the
    -- stock we had just captured never reached the pipeline while the pipeline
    -- was told to consider retiring the vendor.
    --
    -- Records saved before lastScanHadHousing existed fall back to the decor
    -- flag, which on those records IS the housing answer: decor was the only
    -- subclass the pre-HS-249 capture gate could see.
    local hadHousing = vendor.lastScanHadHousing
    if hadHousing == nil then
        hadHousing = vendor.lastScanHadDecor
    end
    if hadHousing == false then
        return true
    end

    local items = vendor.items or {}
    return #items == 0 and (vendor.itemCount or 0) > 0
end

-- Export scanned vendor data
-- fullExport: include vendors already in VendorDatabase
-- exportAll: bypass timestamp filter (export everything scanned)
function ExportImport:ExportScannedVendors(fullExport, exportAll)
    if not HA.Addon or not HA.Addon.db then
        HA.Addon:Print("Database not available.")
        return
    end

    local data = HA.Addon.db.global.scannedVendors
    if not data or not next(data) then
        HA.Addon:Print("No scanned vendor data to export. Visit some vendors first!")
        return
    end

    -- Get last export timestamp for differential exports
    local lastExportTime = HA.Addon.db.global.lastExportTimestamp or 0

    local output = {}
    local vendorCount = 0
    local itemCount = 0
    local skippedPrevExport = 0
    local skippedNoDecor = 0
    local delistedCount = 0
    local hasReportData = false
    local exportedUniqueItems = {}

    table.insert(output, EXPORT_PREFIX .. "\n")
    table.insert(output, "# exportFormatVersion: 2\n")
    -- Client build stamps every export so the data pipeline reads the live
    -- build from scans instead of external checkouts that lag hotfix builds.
    local clientVersion, clientBuild = GetBuildInfo()
    if clientVersion and clientBuild then
        table.insert(output, "# clientBuild: " .. clientVersion .. "." .. clientBuild .. "\n")
    end
    -- HS-251 Stage C: housingCount appended at the END of the row. This is
    -- positional TSV and other columns are indexed by position downstream, so
    -- a mid-row insert would break every existing consumer; append-only is
    -- the only safe way to extend it.
    table.insert(output, "# V: npcID\tname\tmapID\tx\ty\tfaction\ttimestamp\titemCount\tdecorCount\tzone\tsubZone\trealZone\tparentMapID\tcontinentMapID\texpansion\tcurrency\tmapChain\tscanConfidence\thousingCount\n")
    table.insert(output, "# I: npcID\titemID\tname\tprice\tcostData\tisUsable\tisPurchasable\tspellID\trequirements\tdecorID\tmerchantSlot\thasExtendedCost\n")
    table.insert(output, "# D: npcID\tname\tmapID\tx\ty\tzone\ttimestamp (vendor in DB but scanned with 0 housing items)\n")

    -- Collect and sort npcIDs for deterministic output
    local sortedNPCs = {}
    for npcID in pairs(data) do
        table.insert(sortedNPCs, npcID)
    end
    table.sort(sortedNPCs)

    for _, npcID in ipairs(sortedNPCs) do
        local vendor = data[npcID]
        local items = vendor.items or {}
        local shouldProcess = true
        local skipReason = nil

        -- Skip if already exported (unless exportAll is true)
        if not exportAll and (vendor.lastScanned or 0) <= lastExportTime then
            shouldProcess = false
            skipReason = "prev_export"
        end

        -- Handle vendors with no decor items
        if shouldProcess and IsDelistCandidate(vendor, npcID) then
            -- Vendor is in our DB but scanned with 0 housing items — flag for
            -- review. HS-250: housing-wide, not decor-only; a vendor selling
            -- only room plans or dyes is stock, not an empty vendor.
            shouldProcess = false
            skipReason = "delist"
        elseif shouldProcess and #items == 0 then
            -- Not in DB, nothing to export
            shouldProcess = false
            skipReason = "no_decor"
        end

        -- Track skip reasons
        if not shouldProcess then
            if skipReason == "prev_export" then
                skippedPrevExport = skippedPrevExport + 1
            elseif skipReason == "delist" then
                delistedCount = delistedCount + 1
                hasReportData = true
                -- Emit a delist line so we know to update the DB
                local delistLine = string.format("D\t%d\t%s\t%d\t%.4f\t%.4f\t%s\t%d\n",
                    vendor.npcID or npcID,
                    SanitizeExportField(vendor.name or "Unknown"),
                    vendor.mapID or 0,
                    vendor.coords and vendor.coords.x or 0,
                    vendor.coords and vendor.coords.y or 0,
                    SanitizeExportField(vendor.zone or ""),
                    vendor.lastScanned or 0
                )
                table.insert(output, delistLine)
            elseif skipReason == "no_decor" then
                skippedNoDecor = skippedNoDecor + 1
            end
        end

        if shouldProcess then
            hasReportData = true
            vendorCount = vendorCount + 1

            -- VENDOR line: V npcID name mapID x y faction timestamp itemCount decorCount zone subZone realZone parentMapID continentMapID expansion currency mapChain scanConfidence housingCount
            local vendorLine = string.format("V\t%d\t%s\t%d\t%.4f\t%.4f\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\n",
                vendor.npcID or npcID,
                SanitizeExportField(vendor.name or "Unknown"),
                vendor.mapID or 0,
                vendor.coords and vendor.coords.x or 0,
                vendor.coords and vendor.coords.y or 0,
                SanitizeExportField(vendor.faction or "Neutral"),
                vendor.lastScanned or 0,
                vendor.itemCount or #items,
                vendor.decorCount or #items,
                SanitizeExportField(vendor.zone or ""),
                SanitizeExportField(vendor.subZone or ""),
                SanitizeExportField(vendor.realZone or ""),
                vendor.parentMapID and tostring(vendor.parentMapID) or "",
                vendor.continentMapID and tostring(vendor.continentMapID) or "",
                SanitizeExportField(vendor.expansion or ""),
                SanitizeExportField(vendor.currency or ""),
                (vendor.mapChain and #vendor.mapChain > 0) and table.concat(vendor.mapChain, ";") or "",
                tostring(vendor.scanConfidence or "unknown"),
                -- HS-251 Stage C: a housing-only (non-decor) vendor's total stock was
                -- invisible to anything reading only V-rows, since this column used
                -- to be decorCount's job alone. Same fallback idiom decorCount already
                -- uses: pre-housing-gate records have no housingCount, and decorCount
                -- IS the housing count on those (decor was the only subclass the old
                -- gate could see); #items is the last resort for a record with neither.
                vendor.housingCount or vendor.decorCount or #items
            )
            table.insert(output, vendorLine)

            -- Sort items within each vendor for deterministic output
            local sortedItems = {}
            for _, item in ipairs(items) do
                table.insert(sortedItems, item)
            end
            table.sort(sortedItems, function(a, b)
                local idA = HA.VendorData:GetItemID(a)
                local idB = HA.VendorData:GetItemID(b)
                return (idA or 0) < (idB or 0)
            end)

            -- ITEM lines: I npcID itemID name price costData isUsable isPurchasable spellID requirements decorID merchantSlot hasExtendedCost
            for _, item in ipairs(sortedItems) do
                local itemID = HA.VendorData:GetItemID(item)
                if itemID then
                    itemCount = itemCount + 1
                    exportedUniqueItems[itemID] = true

                    local itemName = item.name or ""
                    local price = item.price or 0
                    local costData = FormatCostData(item.currencies, item.itemCosts)

                    -- Format: I npcID itemID name price costData isUsable isPurchasable spellID requirements decorID merchantSlot hasExtendedCost
                    local itemLine = string.format("I\t%d\t%d\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                        vendor.npcID or npcID,
                        itemID,
                        SanitizeExportField(itemName),
                        price,
                        costData,
                        item.isUsable == nil and "" or tostring(item.isUsable),
                        item.isPurchasable == nil and "" or tostring(item.isPurchasable),
                        item.spellID and tostring(item.spellID) or "",
                        FormatRequirements(item.requirements),
                        item.decorID and tostring(item.decorID) or "",
                        tostring(item.merchantSlot or ""),
                        item.hasExtendedCost == nil and "" or tostring(item.hasExtendedCost)
                    )
                    table.insert(output, itemLine)
                end
            end
        end
    end

    -- Export source summary comments (primary-only categorization, one bucket per unique item).
    local uniqueItemCount = 0
    for _ in pairs(exportedUniqueItems) do
        uniqueItemCount = uniqueItemCount + 1
    end
    local sourceCounts = GetPrimarySourceCounts(exportedUniqueItems)
    table.insert(output, 3, "# sourceSummaryMode: primary (one bucket per unique exported item)\n")
    table.insert(output, 4, string.format(
        "# sourceSummary: uniqueItems=%d\tvendor=%d\tquest=%d\tachievement=%d\tprofession=%d\tevent=%d\tdrop=%d\tunknown=%d\n",
        uniqueItemCount,
        sourceCounts.vendor or 0,
        sourceCounts.quest or 0,
        sourceCounts.achievement or 0,
        sourceCounts.profession or 0,
        sourceCounts.event or 0,
        sourceCounts.drop or 0,
        sourceCounts.unknown or 0
    ))

    -- Print summary with skip details
    local skipMsg = ""
    if skippedPrevExport > 0 or skippedNoDecor > 0 then
        local parts = {}
        if skippedPrevExport > 0 then
            table.insert(parts, skippedPrevExport .. " previously exported")
        end
        if skippedNoDecor > 0 then
            table.insert(parts, skippedNoDecor .. " no decor items")
        end
        skipMsg = " (" .. table.concat(parts, ", ") .. " skipped)"
    end
    if delistedCount > 0 then
        skipMsg = skipMsg .. string.format(" [%d flagged for delist - in DB but 0 housing items]", delistedCount)
    end

    if exportAll then
        HA.Addon:Print(string.format("Export ALL: %d vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    else
        HA.Addon:Print(string.format("Exported %d vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    end

    -- Show output and update timestamp
    if hasReportData then
        if HA.Analytics then
            HA.Analytics:IncrementCounter("Exports")
        end

        -- Update last export timestamp
        HA.Addon.db.global.lastExportTimestamp = time()

        if HA.OutputWindow then
            HA.OutputWindow:Show("Export Data", table.concat(output))
        else
            for _, line in ipairs(output) do
                HA.Addon:Print(line)
            end
        end
    else
        HA.Addon:Print("Nothing new to export. All scanned data is already exported or has no decor items.")
    end
end

-------------------------------------------------------------------------------
-- Clear Scanned Data
-------------------------------------------------------------------------------

function ExportImport:ClearScannedData()
    -- Delegate to VendorScanner (single source of truth for clear behavior)
    if HA.VendorScanner and HA.VendorScanner.ClearScannedData then
        HA.VendorScanner:ClearScannedData()
    else
        HA.Addon:Print("VendorScanner not available.")
    end
end

-------------------------------------------------------------------------------
-- Slash Command Integration
-------------------------------------------------------------------------------

-- These get registered in core.lua:
-- /hs export - shows export dialog
-- /hs exportall - exports all scanned data (bypasses timestamp filter)
-- /hs clearscans - clears all scanned vendor data

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("ExportImport", ExportImport)
end
