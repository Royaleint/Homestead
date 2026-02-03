--[[
    Homestead - Export/Import Module
    Allows users to export and import scanned vendor data for community sharing
]]

local addonName, HA = ...

local ExportImport = {}
HA.ExportImport = ExportImport

local EXPORT_VERSION_V1 = "V1"
local EXPORT_VERSION_V2 = "V2"
local EXPORT_PREFIX_V1 = "HOMESTEAD_EXPORT_" .. EXPORT_VERSION_V1 .. ":"
local EXPORT_PREFIX_V2 = "HOMESTEAD_VENDOR_EXPORT_" .. EXPORT_VERSION_V2 .. ":"

local function GetNewItems(scannedDecor, existingItems)
    if not scannedDecor or #scannedDecor == 0 then
        return {}
    end

    -- Build lookup of existing items for O(1) checks
    local existingLookup = {}
    if existingItems then
        for _, itemID in ipairs(existingItems) do
            existingLookup[itemID] = true
        end
    end

    -- Find items in scanned that aren't in existing
    local newItems = {}
    for _, item in ipairs(scannedDecor) do
        if item.itemID and not existingLookup[item.itemID] then
            table.insert(newItems, item.itemID)
        end
    end

    return newItems
end

-------------------------------------------------------------------------------
-- Export Frame (Copyable Text)
-------------------------------------------------------------------------------

local exportFrame = nil

local function CreateExportFrame()
    if exportFrame then return exportFrame end
    
    local f = CreateFrame("Frame", "HomesteadExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(600, 200)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
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
    title:SetPoint("TOP", 0, -10)
    title:SetText("Homestead Export")
    f.title = title
    
    -- Instructions
    local instructions = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -5)
    instructions:SetText("Press Ctrl+C to copy, then share with the community")
    f.instructions = instructions
    
    -- Scroll frame for edit box
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 45)
    
    -- Edit box
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    editBox:SetScript("OnTextChanged", function(self)
        -- Auto-adjust height based on content
        local _, fontHeight = self:GetFont()
        local text = self:GetText()
        local numLines = 1
        for _ in text:gmatch("\n") do
            numLines = numLines + 1
        end
        self:SetHeight(math.max(scrollFrame:GetHeight(), numLines * (fontHeight + 2)))
    end)
    scrollFrame:SetScrollChild(editBox)
    f.editBox = editBox
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOM", 0, 10)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    -- Stats text
    local stats = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stats:SetPoint("BOTTOMLEFT", 15, 15)
    stats:SetTextColor(0.7, 0.7, 0.7)
    f.stats = stats
    
    exportFrame = f
    return f
end

local function ShowExportFrame(text, vendorCount, itemCount)
    local f = CreateExportFrame()
    f.title:SetText("Homestead Export")
    f.instructions:SetText("Press Ctrl+C to copy, then share with the community")
    f.editBox:SetText(text)
    f.editBox:HighlightText()
    f.editBox:SetCursorPosition(0)
    f.stats:SetText(string.format("Vendors: %d | Items: %d", vendorCount, itemCount))
    f:Show()
    f.editBox:SetFocus()
end

local function ShowImportFrame()
    local f = CreateExportFrame()
    f.title:SetText("Homestead Import")
    f.instructions:SetText("Paste export data below and press Enter")
    f.editBox:SetText("")
    f.stats:SetText("Paste HOMESTEAD_EXPORT data here")
    
    -- Temporarily change behavior for import
    f.editBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text and text ~= "" then
            ExportImport:ImportData(text)
            f:Hide()
        end
    end)
    
    f:Show()
    f.editBox:SetFocus()
end

local exportDialogFrame = nil

local function CreateExportDialog()
    if exportDialogFrame then return exportDialogFrame end

    local f = CreateFrame("Frame", "HomesteadExportDialog", UIParent, "BackdropTemplate")
    f:SetSize(280, 200)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
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
    desc:SetText("Choose export format:")

    -- V2 New Scans export button (recommended)
    local v2Btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    v2Btn:SetSize(200, 26)
    v2Btn:SetPoint("TOP", desc, "BOTTOM", 0, -12)
    v2Btn:SetText("V2 New Scans (Recommended)")
    v2Btn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendorsV2(false, false)
    end)

    -- Tooltip for V2 button
    v2Btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("V2 New Scans Export", 1, 1, 1)
        GameTooltip:AddLine("Exports vendors scanned since last export.", 1, 0.82, 0, true)
        GameTooltip:AddLine("Includes: price, currencies, faction, catalog info", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    v2Btn:SetScript("OnLeave", GameTooltip_Hide)

    -- V2 Export All button
    local v2FullBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    v2FullBtn:SetSize(200, 26)
    v2FullBtn:SetPoint("TOP", v2Btn, "BOTTOM", 0, -6)
    v2FullBtn:SetText("V2 Export All")
    v2FullBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendorsV2(true, true)
    end)

    -- Tooltip for V2 full button
    v2FullBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("V2 Export All", 1, 1, 1)
        GameTooltip:AddLine("Exports ALL scanned vendors, bypassing", 1, 0.82, 0, true)
        GameTooltip:AddLine("the timestamp filter.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    v2FullBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Separator
    local sep = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sep:SetPoint("TOP", v2FullBtn, "BOTTOM", 0, -8)
    sep:SetText("-- Legacy Formats --")

    -- V1 Differential export button
    local diffBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    diffBtn:SetSize(200, 26)
    diffBtn:SetPoint("TOP", sep, "BOTTOM", 0, -6)
    diffBtn:SetText("V1 New Data Only")
    diffBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendors(false)
    end)

    -- Tooltip for V1 differential button
    diffBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("V1 Differential Export", 1, 1, 1)
        GameTooltip:AddLine("Legacy format - item IDs only.", 1, 0.82, 0, true)
        GameTooltip:AddLine("Only exports new vendors/items.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    diffBtn:SetScript("OnLeave", GameTooltip_Hide)

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

function ExportImport:ExportScannedVendors(fullExport)
    if not HA.Addon or not HA.Addon.db then
        HA.Addon:Print("Database not available.")
        return
    end

    local data = HA.Addon.db.global.scannedVendors
    if not data or not next(data) then
        HA.Addon:Print("No scanned vendor data to export. Visit some vendors first!")
        return
    end

    local output = {}
    local newVendors = 0
    local updatedVendors = 0
    local skippedVendors = 0
    local totalItems = 0

    table.insert(output, EXPORT_PREFIX_V1 .. "\n")

    for npcID, vendor in pairs(data) do
        local itemsToExport = {}
        local exportReason = nil

        if fullExport then
            -- Full export: include all items
            if vendor.decor then
                for _, item in ipairs(vendor.decor) do
                    if item.itemID then
                        table.insert(itemsToExport, item.itemID)
                    end
                end
            end
            if #itemsToExport > 0 or not HA.VendorDatabase:HasVendor(npcID) then
                exportReason = "full"
            end
        else
            -- Differential export: check against VendorDatabase
            local existingVendor = HA.VendorDatabase:GetVendor(npcID)

            if not existingVendor then
                -- New vendor not in database
                if vendor.decor then
                    for _, item in ipairs(vendor.decor) do
                        if item.itemID then
                            table.insert(itemsToExport, item.itemID)
                        end
                    end
                end
                exportReason = "new"
                newVendors = newVendors + 1
            else
                -- Existing vendor - check for new items
                local newItems = GetNewItems(vendor.decor, existingVendor.items)
                if #newItems > 0 then
                    itemsToExport = newItems
                    exportReason = "updated"
                    updatedVendors = updatedVendors + 1
                else
                    skippedVendors = skippedVendors + 1
                end
            end
        end

        -- Only add to output if there's a reason to export
        if exportReason then
            totalItems = totalItems + #itemsToExport

            local entry = string.format(
                "%d\t%s\t%d\t%.4f\t%.4f\t%d\t%d\t%s;\n",
                vendor.npcID or npcID,
                (vendor.name or "Unknown"):gsub("\t", " "),
                vendor.mapID or 0,
                vendor.coords and vendor.coords.x or 0,
                vendor.coords and vendor.coords.y or 0,
                vendor.lastScanned or 0,
                #itemsToExport,
                table.concat(itemsToExport, ",")
            )
            table.insert(output, entry)
        end
    end

    -- Print summary
    if fullExport then
        local totalVendors = 0
        for _ in pairs(data) do totalVendors = totalVendors + 1 end
        HA.Addon:Print(string.format("Full export: %d vendors with %d items.", totalVendors, totalItems))
    else
        HA.Addon:Print(string.format("Differential export: %d new, %d updated, %d skipped (already in database).",
            newVendors, updatedVendors, skippedVendors))
    end

    -- Show output if there's anything to export
    if #output > 1 then
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
-- V2 Export (Enhanced Data)
-- Exports full item data: price, currencies, catalogInfo
-------------------------------------------------------------------------------

-- Format cost data as "c3008:100,i12345:5" string
-- c = currency, i = item cost
local function FormatCostData(currencies, itemCosts)
    local parts = {}

    -- Add currencies with 'c' prefix
    if currencies then
        for _, c in ipairs(currencies) do
            if c.currencyID and c.amount then
                table.insert(parts, "c" .. c.currencyID .. ":" .. c.amount)
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

-- Legacy function for backwards compatibility
local function FormatCurrencyData(currencies)
    return FormatCostData(currencies, nil)
end

-- Export with enhanced V2 format
-- fullExport: include vendors already in VendorDatabase
-- exportAll: bypass timestamp filter (export everything scanned)
function ExportImport:ExportScannedVendorsV2(fullExport, exportAll)
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

    table.insert(output, EXPORT_PREFIX_V2 .. "\n")

    for npcID, vendor in pairs(data) do
        -- Get items from either 'items' (new format) or 'decor' (old format)
        local items = vendor.items or vendor.decor or {}
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
                        local itemID = type(item) == "table" and item[1] or item
                        existingLookup[itemID] = true
                    end
                end

                local hasNewItems = false
                for _, item in ipairs(items) do
                    local itemID = item.itemID or (type(item) == "table" and item[1]) or item
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

            -- VENDOR line: V:npcID	name	mapID	x	y	faction	timestamp	itemCount	decorCount
            local vendorLine = string.format("V\t%d\t%s\t%d\t%.4f\t%.4f\t%s\t%d\t%d\t%d\n",
                vendor.npcID or npcID,
                (vendor.name or "Unknown"):gsub("\t", " "),
                vendor.mapID or 0,
                vendor.coords and vendor.coords.x or 0,
                vendor.coords and vendor.coords.y or 0,
                vendor.faction or "Neutral",
                vendor.lastScanned or 0,
                vendor.itemCount or #items,
                vendor.decorCount or #items
            )
            table.insert(output, vendorLine)

            -- ITEM lines: I:npcID	itemID	name	price	currencyData	entrySubtype
            for _, item in ipairs(items) do
                local itemID = item.itemID or (type(item) == "table" and item[1]) or item
                if itemID then
                    itemCount = itemCount + 1

                    local itemName = item.name or ""
                    local price = item.price or 0
                    local costData = FormatCostData(item.currencies, item.itemCosts)

                    -- Format: I	npcID	itemID	name	price	costData
                    local itemLine = string.format("I\t%d\t%d\t%s\t%d\t%s\n",
                        vendor.npcID or npcID,
                        itemID,
                        itemName:gsub("\t", " "),
                        price,
                        costData
                    )
                    table.insert(output, itemLine)
                end
            end
        end
    end

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
        HA.Addon:Print(string.format("V2 Export ALL: %d vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    elseif fullExport then
        HA.Addon:Print(string.format("V2 Full export: %d vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    else
        HA.Addon:Print(string.format("V2 Exported %d new vendors, %d items.%s", vendorCount, itemCount, skipMsg))
    end

    -- Show output and update timestamp
    if vendorCount > 0 then
        -- Update last export timestamp
        HA.Addon.db.global.lastExportTimestamp = time()

        if HA.OutputWindow then
            HA.OutputWindow:Show("Export Data (V2)", table.concat(output))
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
-- Import Functions
-------------------------------------------------------------------------------

-- Parse cost data string "c3008:100,i12345:5" back to tables
-- Returns: currencies, itemCosts
local function ParseCostData(costStr)
    if not costStr or costStr == "" then
        return nil, nil
    end

    local currencies = {}
    local itemCosts = {}

    for pair in costStr:gmatch("[^,]+") do
        -- New format: c3008:100 or i12345:5
        local costType, id, amount = pair:match("^([ci])(%d+):(%d+)$")
        if costType and id and amount then
            if costType == "c" then
                table.insert(currencies, {
                    currencyID = tonumber(id),
                    amount = tonumber(amount),
                })
            else -- costType == "i"
                table.insert(itemCosts, {
                    itemID = tonumber(id),
                    amount = tonumber(amount),
                })
            end
        else
            -- Legacy format: 3008:100 (assume currency)
            id, amount = pair:match("^(%d+):(%d+)$")
            if id and amount then
                table.insert(currencies, {
                    currencyID = tonumber(id),
                    amount = tonumber(amount),
                })
            end
        end
    end

    return (#currencies > 0 and currencies or nil), (#itemCosts > 0 and itemCosts or nil)
end

-- Legacy function for backwards compatibility
local function ParseCurrencyData(currencyStr)
    local currencies, _ = ParseCostData(currencyStr)
    return currencies
end

function ExportImport:ImportData(input)
    if not input or input == "" then
        HA.Addon:Print("No data to import.")
        return
    end

    -- Detect format version
    local isV2 = input:match("^HOMESTEAD_VENDOR_EXPORT_V2:")
    local isV1 = input:match("^HOMESTEAD_EXPORT_V1:")

    if not isV1 and not isV2 then
        HA.Addon:Print("Invalid or unsupported import format.")
        HA.Addon:Print("Expected: HOMESTEAD_EXPORT_V1: or HOMESTEAD_VENDOR_EXPORT_V2:")
        return
    end

    if isV2 then
        self:ImportDataV2(input)
    else
        self:ImportDataV1(input)
    end
end

-- V1 Import (legacy format)
function ExportImport:ImportDataV1(input)
    local data = input:gsub("^HOMESTEAD_EXPORT_V1:", "")
    if not data or data == "" then
        HA.Addon:Print("No vendor data found in import.")
        return
    end

    local imported = 0
    local updated = 0
    local skipped = 0

    for entry in data:gmatch("[^;\r\n]+") do
        local parts = {strsplit("\t", entry)}
        local npcID = tonumber(parts[1])
        local name = parts[2]
        local mapID = tonumber(parts[3])
        local x = tonumber(parts[4])
        local y = tonumber(parts[5])
        local lastScanned = tonumber(parts[6])
        local itemCount = tonumber(parts[7]) or 0
        local itemIDsStr = parts[8] or ""

        if npcID and name and name ~= "" then
            local existing = HA.Addon.db.global.scannedVendors[npcID]

            -- Parse item IDs
            local decor = {}
            if itemIDsStr ~= "" then
                for itemID in itemIDsStr:gmatch("(%d+)") do
                    table.insert(decor, {itemID = tonumber(itemID)})
                end
            end

            if not existing then
                -- New vendor
                HA.Addon.db.global.scannedVendors[npcID] = {
                    npcID = npcID,
                    name = name,
                    mapID = mapID,
                    coords = {x = x, y = y},
                    lastScanned = lastScanned,
                    decor = decor,
                    importedFrom = "community",
                    importedAt = time(),
                }
                imported = imported + 1
            elseif lastScanned > (existing.lastScanned or 0) then
                -- Update with newer data
                existing.mapID = mapID
                existing.coords = {x = x, y = y}
                existing.lastScanned = lastScanned
                if #decor > #(existing.decor or {}) then
                    existing.decor = decor
                end
                existing.importedFrom = "community"
                existing.importedAt = time()
                updated = updated + 1
            else
                skipped = skipped + 1
            end
        end
    end

    HA.Addon:Print(string.format("V1 Import complete: %d new, %d updated, %d skipped.",
        imported, updated, skipped))

    -- Refresh map pins if any data changed
    if imported > 0 or updated > 0 then
        if HA.VendorMapPins and HA.VendorMapPins.RefreshAllPins then
            HA.VendorMapPins:RefreshAllPins()
        end
    end
end

-- V2 Import (enhanced format with full item data)
function ExportImport:ImportDataV2(input)
    local data = input:gsub("^HOMESTEAD_VENDOR_EXPORT_V2:", "")
    if not data or data == "" then
        HA.Addon:Print("No vendor data found in import.")
        return
    end

    local imported = 0
    local updated = 0
    local skipped = 0
    local itemsImported = 0

    -- First pass: collect vendors and items
    local vendors = {}
    local vendorItems = {}

    for line in data:gmatch("[^\r\n]+") do
        local lineType = line:sub(1, 1)
        local lineData = line:sub(3)  -- Skip "V\t" or "I\t"

        if lineType == "V" then
            -- VENDOR line: npcID	name	mapID	x	y	faction	timestamp	itemCount	decorCount
            local parts = {strsplit("\t", lineData)}
            local npcID = tonumber(parts[1])
            if npcID then
                vendors[npcID] = {
                    npcID = npcID,
                    name = parts[2],
                    mapID = tonumber(parts[3]),
                    x = tonumber(parts[4]),
                    y = tonumber(parts[5]),
                    faction = parts[6],
                    lastScanned = tonumber(parts[7]),
                    itemCount = tonumber(parts[8]),
                    decorCount = tonumber(parts[9]),
                }
                vendorItems[npcID] = {}
            end
        elseif lineType == "I" then
            -- ITEM line: npcID	itemID	name	price	costData
            local parts = {strsplit("\t", lineData)}
            local npcID = tonumber(parts[1])
            local itemID = tonumber(parts[2])
            if npcID and itemID and vendorItems[npcID] then
                local currencies, itemCosts = ParseCostData(parts[5])
                table.insert(vendorItems[npcID], {
                    itemID = itemID,
                    name = parts[3],
                    price = tonumber(parts[4]),
                    currencies = currencies,
                    itemCosts = itemCosts,
                    isDecor = true,
                })
                itemsImported = itemsImported + 1
            end
        end
    end

    -- Second pass: merge into SavedVariables
    for npcID, vendorData in pairs(vendors) do
        local existing = HA.Addon.db.global.scannedVendors[npcID]
        local items = vendorItems[npcID] or {}

        if not existing then
            -- New vendor
            HA.Addon.db.global.scannedVendors[npcID] = {
                npcID = npcID,
                name = vendorData.name,
                mapID = vendorData.mapID,
                coords = {x = vendorData.x, y = vendorData.y},
                faction = vendorData.faction,
                lastScanned = vendorData.lastScanned,
                itemCount = vendorData.itemCount,
                decorCount = vendorData.decorCount,
                hasDecor = #items > 0,
                items = items,
                importedFrom = "community_v2",
                importedAt = time(),
            }
            imported = imported + 1
        elseif vendorData.lastScanned > (existing.lastScanned or 0) then
            -- Update with newer data
            existing.mapID = vendorData.mapID
            existing.coords = {x = vendorData.x, y = vendorData.y}
            existing.faction = vendorData.faction
            existing.lastScanned = vendorData.lastScanned
            existing.itemCount = vendorData.itemCount
            existing.decorCount = vendorData.decorCount
            -- Replace items with imported data if it has more items
            if #items > #(existing.items or existing.decor or {}) then
                existing.items = items
                existing.decor = nil  -- Remove old format
            end
            existing.hasDecor = #(existing.items or {}) > 0
            existing.importedFrom = "community_v2"
            existing.importedAt = time()
            updated = updated + 1
        else
            skipped = skipped + 1
        end
    end

    HA.Addon:Print(string.format("V2 Import complete: %d new, %d updated, %d skipped, %d items.",
        imported, updated, skipped, itemsImported))

    -- Refresh map pins if any data changed
    if imported > 0 or updated > 0 then
        if HA.VendorMapPins and HA.VendorMapPins.RefreshAllPins then
            HA.VendorMapPins:RefreshAllPins()
        end
    end
end

-------------------------------------------------------------------------------
-- Show Import Dialog
-------------------------------------------------------------------------------

function ExportImport:ShowImportDialog()
    ShowImportFrame()
end

-------------------------------------------------------------------------------
-- Clear Scanned Data
-------------------------------------------------------------------------------

function ExportImport:ClearScannedData()
    if not HA.Addon or not HA.Addon.db or not HA.Addon.db.global then
        HA.Addon:Print("Database not available.")
        return
    end

    local count = 0
    if HA.Addon.db.global.scannedVendors then
        for _ in pairs(HA.Addon.db.global.scannedVendors) do
            count = count + 1
        end
    end

    -- Clear scanned vendors
    HA.Addon.db.global.scannedVendors = {}

    -- Also reset export timestamp
    HA.Addon.db.global.lastExportTimestamp = nil

    HA.Addon:Print(string.format("Cleared %d scanned vendor(s) and reset export timestamp.", count))

    -- Refresh map pins
    if HA.VendorMapPins and HA.VendorMapPins.RefreshAllPins then
        HA.VendorMapPins:RefreshAllPins()
    end
end

-------------------------------------------------------------------------------
-- Slash Command Integration
-------------------------------------------------------------------------------

-- These get registered in core.lua:
-- /hs export - shows export dialog (V1 and V2 options)
-- /hs exportall - exports all scanned data (bypasses timestamp filter)
-- /hs clearscans - clears all scanned vendor data
-- /hs import - calls ExportImport:ShowImportDialog()

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("ExportImport", ExportImport)
end
