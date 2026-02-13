--[[
    Homestead - Export/Import Module
    Allows users to export and import scanned vendor data for community sharing
]]

local addonName, HA = ...

local ExportImport = {}
HA.ExportImport = ExportImport

local EXPORT_PREFIX = "HOMESTEAD_VENDOR_EXPORT_V2:"

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
    tinsert(UISpecialFrames, "HomesteadExportFrame")
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
    f.editBox:SetScript("OnEnterPressed", nil)
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
    f:SetSize(280, 155)
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

-- Unescape requirement values on import
local function UnescapeReqValue(str)
    if not str then return "" end
    str = str:gsub("%%2C", ",")
    str = str:gsub("%%3B", ";")
    str = str:gsub("%%25", "%%")
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

-- Parse requirements string from import
-- "" or missing → nil, "R:none" → {}, "R:..." → parsed table
local function ParseRequirements(str)
    if not str or str == "" then return nil end
    if str == "R:none" then return {} end

    local prefix = str:sub(1, 2)
    if prefix ~= "R:" then return nil end

    local reqs = {}
    local data = str:sub(3)
    for entry in data:gmatch("[^;]+") do
        local req = {}
        local first = true
        for token in entry:gmatch("[^,]+") do
            if first then
                req.type = UnescapeReqValue(token)
                first = false
            else
                local key, val = token:match("^(.-)=(.+)$")
                if key and val then
                    if key == "id" or key == "level" then
                        req[key] = tonumber(val)
                    else
                        req[key] = UnescapeReqValue(val)
                    end
                end
            end
        end
        if req.type then
            table.insert(reqs, req)
        end
    end
    return reqs
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
                        local existItemID = HA.VendorData and HA.VendorData:GetItemID(item) or (type(item) == "table" and item[1] or item)
                        existingLookup[existItemID] = true
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
                local idA = type(a) == "table" and a.itemID or a
                local idB = type(b) == "table" and b.itemID or b
                return (idA or 0) < (idB or 0)
            end)

            -- ITEM lines: I npcID itemID name price costData isUsable spellID
            for _, item in ipairs(sortedItems) do
                local itemID = item.itemID or (type(item) == "table" and item[1]) or item
                if itemID then
                    itemCount = itemCount + 1

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
            -- Name-only currency format: nEscapedName:amount
            local escapedName, nameAmount = pair:match("^n(.+):(%d+)$")
            if escapedName and nameAmount then
                local name = escapedName:gsub("%%2C", ","):gsub("%%3A", ":")
                table.insert(currencies, {
                    name = name,
                    amount = tonumber(nameAmount),
                })
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
    end

    return (#currencies > 0 and currencies or nil), (#itemCosts > 0 and itemCosts or nil)
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

    -- Rebuild indexes and refresh map pins if any data changed
    if imported > 0 or updated > 0 then
        if HA.VendorData then
            HA.VendorData:BuildScannedIndex()
        end
        if HA.VendorMapPins then
            HA.VendorMapPins:InvalidateAllCaches()
            if WorldMapFrame and WorldMapFrame:IsShown() then
                HA.VendorMapPins:RefreshPins()
            end
            HA.VendorMapPins:RefreshMinimapPins()
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

        if lineType == "#" then
            -- Skip header comments
        elseif lineType == "V" then
            local lineData = line:sub(3)  -- Skip "V\t"
            -- VENDOR line: npcID name mapID x y faction timestamp itemCount decorCount zone subZone parentMapID expansion currency
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
                    -- New V2 fields (nil if not present in older exports)
                    zone = parts[10] and parts[10] ~= "" and parts[10] or nil,
                    subZone = parts[11] and parts[11] ~= "" and parts[11] or nil,
                    parentMapID = tonumber(parts[12]),
                    expansion = parts[13] and parts[13] ~= "" and parts[13] or nil,
                    currency = parts[14] and parts[14] ~= "" and parts[14] or nil,
                }
                vendorItems[npcID] = {}
            end
        elseif lineType == "I" then
            local lineData = line:sub(3)  -- Skip "I\t"
            -- ITEM line: npcID itemID name price costData isUsable spellID
            local parts = {strsplit("\t", lineData)}
            local npcID = tonumber(parts[1])
            local itemID = tonumber(parts[2])
            if npcID and itemID and vendorItems[npcID] then
                local currencies, itemCosts = ParseCostData(parts[5])
                -- Parse isUsable: "true"/"false"/""→nil
                local isUsable = nil
                if parts[6] == "true" then isUsable = true
                elseif parts[6] == "false" then isUsable = false end
                table.insert(vendorItems[npcID], {
                    itemID = itemID,
                    name = parts[3],
                    price = tonumber(parts[4]),
                    currencies = currencies,
                    itemCosts = itemCosts,
                    isUsable = isUsable,
                    spellID = tonumber(parts[7]),
                    requirements = ParseRequirements(parts[8]),
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
                zone = vendorData.zone,
                subZone = vendorData.subZone,
                parentMapID = vendorData.parentMapID,
                expansion = vendorData.expansion,
                currency = vendorData.currency,
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
            existing.zone = vendorData.zone
            existing.subZone = vendorData.subZone
            existing.parentMapID = vendorData.parentMapID
            existing.expansion = vendorData.expansion
            existing.currency = vendorData.currency
            existing.lastScanned = vendorData.lastScanned
            existing.itemCount = vendorData.itemCount
            existing.decorCount = vendorData.decorCount
            -- Replace items with imported data if it has more items
            if #items > #(existing.items or existing.decor or {}) then
                existing.items = items
                existing.decor = nil  -- Remove old format
            end
            existing.hasDecor = #(existing.items or existing.decor or {}) > 0
            existing.importedFrom = "community_v2"
            existing.importedAt = time()
            updated = updated + 1
        else
            skipped = skipped + 1
        end
    end

    HA.Addon:Print(string.format("V2 Import complete: %d new, %d updated, %d skipped, %d items.",
        imported, updated, skipped, itemsImported))

    -- Rebuild indexes and refresh map pins if any data changed
    if imported > 0 or updated > 0 then
        if HA.VendorData then
            HA.VendorData:BuildScannedIndex()
        end
        if HA.VendorMapPins then
            HA.VendorMapPins:InvalidateAllCaches()
            if WorldMapFrame and WorldMapFrame:IsShown() then
                HA.VendorMapPins:RefreshPins()
            end
            HA.VendorMapPins:RefreshMinimapPins()
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
-- /hs import - calls ExportImport:ShowImportDialog()

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("ExportImport", ExportImport)
end

