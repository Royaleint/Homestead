--[[
    Homestead - Export Module
    Allows users to export scanned vendor data for community sharing
]]

local _, HA = ...

local ExportImport = {}
HA.ExportImport = ExportImport

local EXPORT_PREFIX = "HOMESTEAD_EXPORT:"

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
    tinsert(UISpecialFrames, "HomesteadExportDialog")
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
    title:SetText("Export Vendor Data")

    -- Description
    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -8)
    desc:SetWidth(250)
    desc:SetText("Choose export option:")

    -- New Scans export button
    local newBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    newBtn:SetSize(200, 26)
    newBtn:SetPoint("TOP", desc, "BOTTOM", 0, -12)
    newBtn:SetText("Export New Scans")
    newBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendors(false, false)
    end)

    -- Tooltip for new scans button
    newBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Export New Scans", 1, 1, 1)
        GameTooltip:AddLine("Exports vendors scanned since last export.", 1, 0.82, 0, true)
        GameTooltip:AddLine("Includes: price, currencies, faction, catalog info", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    newBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Export All button
    local allBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    allBtn:SetSize(200, 26)
    allBtn:SetPoint("TOP", newBtn, "BOTTOM", 0, -6)
    allBtn:SetText("Export All")
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
    local skippedInDatabase = 0
    local exportedUniqueItems = {}

    table.insert(output, EXPORT_PREFIX .. "\n")
    table.insert(output, "# V: npcID\tname\tmapID\tx\ty\tfaction\ttimestamp\titemCount\tdecorCount\tzone\tsubZone\tparentMapID\texpansion\tcurrency\n")
    table.insert(output, "# I: npcID\titemID\tname\tprice\tcostData\tisUsable\tspellID\trequirements\n")

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

        -- Skip if no items and not doing full export of empty vendors
        if shouldProcess and #items == 0 and not fullExport then
            -- Check if this is a new vendor not in database
            if HA.VendorDatabase:HasVendor(npcID) then
                -- Skip - already in database with no new items
                shouldProcess = false
                skipReason = "in_database"
            end
        end

        -- Skip if differential and vendor already fully in database
        if shouldProcess and not fullExport then
            local existingVendor = HA.VendorDatabase:GetVendor(npcID)
            if existingVendor then
                -- Check if we have any new items
                local existingLookup = {}
                if existingVendor.items then
                    for _, item in ipairs(existingVendor.items) do
                        local existItemID = HA.VendorData:GetItemID(item)
                        existingLookup[existItemID] = true
                    end
                end

                local hasNewItems = false
                for _, item in ipairs(items) do
                    local itemID = HA.VendorData:GetItemID(item)
                    if itemID and not existingLookup[itemID] then
                        hasNewItems = true
                        break
                    end
                end

                if not hasNewItems then
                    shouldProcess = false
                    skipReason = "in_database"
                end
            end
        end

        -- Track skip reasons
        if not shouldProcess then
            if skipReason == "prev_export" then
                skippedPrevExport = skippedPrevExport + 1
            elseif skipReason == "in_database" then
                skippedInDatabase = skippedInDatabase + 1
            end
        end

        if shouldProcess then
            vendorCount = vendorCount + 1

            -- VENDOR line: V npcID name mapID x y faction timestamp itemCount decorCount zone subZone parentMapID expansion currency
            local vendorLine = string.format("V\t%d\t%s\t%d\t%.4f\t%.4f\t%s\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\n",
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
                vendor.parentMapID and tostring(vendor.parentMapID) or "",
                SanitizeExportField(vendor.expansion or ""),
                SanitizeExportField(vendor.currency or "")
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

            -- ITEM lines: I npcID itemID name price costData isUsable spellID
            for _, item in ipairs(sortedItems) do
                local itemID = HA.VendorData:GetItemID(item)
                if itemID then
                    itemCount = itemCount + 1
                    exportedUniqueItems[itemID] = true

                    local itemName = item.name or ""
                    local price = item.price or 0
                    local costData = FormatCostData(item.currencies, item.itemCosts)

                    -- Format: I npcID itemID name price costData isUsable spellID requirements
                    local itemLine = string.format("I\t%d\t%d\t%s\t%d\t%s\t%s\t%s\t%s\n",
                        vendor.npcID or npcID,
                        itemID,
                        SanitizeExportField(itemName),
                        price,
                        costData,
                        item.isUsable == nil and "" or tostring(item.isUsable),
                        item.spellID and tostring(item.spellID) or "",
                        FormatRequirements(item.requirements)
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
    if skippedPrevExport > 0 or skippedInDatabase > 0 then
        local parts = {}
        if skippedPrevExport > 0 then
            table.insert(parts, skippedPrevExport .. " previously exported")
        end
        if skippedInDatabase > 0 then
            table.insert(parts, skippedInDatabase .. " already in database")
        end
        skipMsg = " (" .. table.concat(parts, ", ") .. " skipped)"
    end

    if exportAll then
        HA.Addon:Print(string.format("Export ALL: %d vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    elseif fullExport then
        HA.Addon:Print(string.format("Full export: %d vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    else
        HA.Addon:Print(string.format("Exported %d new vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    end

    -- Show output and update timestamp
    if vendorCount > 0 then
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
        HA.Addon:Print("Nothing new to export. All scanned data is already in VendorDatabase.")
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
