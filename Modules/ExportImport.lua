--[[
    Homestead - Export/Import Module
    Allows users to export and import scanned vendor data for community sharing
]]

local addonName, HA = ...

local ExportImport = {}
HA.ExportImport = ExportImport

local EXPORT_VERSION = "V1"
local EXPORT_PREFIX = "HOMESTEAD_EXPORT_" .. EXPORT_VERSION .. ":"

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
    f:SetSize(280, 140)
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
    desc:SetText("Choose what to export:")

    -- Differential export button
    local diffBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    diffBtn:SetSize(200, 26)
    diffBtn:SetPoint("TOP", desc, "BOTTOM", 0, -12)
    diffBtn:SetText("Export New Data Only")
    diffBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendors(false)
    end)

    -- Tooltip for differential button
    diffBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Differential Export", 1, 1, 1)
        GameTooltip:AddLine("Only exports vendors not yet in the database,", 1, 0.82, 0, true)
        GameTooltip:AddLine("or vendors with new items discovered.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    diffBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Full export button
    local fullBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    fullBtn:SetSize(200, 26)
    fullBtn:SetPoint("TOP", diffBtn, "BOTTOM", 0, -6)
    fullBtn:SetText("Export All Scanned Data")
    fullBtn:SetScript("OnClick", function()
        f:Hide()
        ExportImport:ExportScannedVendors(true)
    end)

    -- Tooltip for full button
    fullBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Full Export", 1, 1, 1)
        GameTooltip:AddLine("Exports all scanned vendor data,", 1, 0.82, 0, true)
        GameTooltip:AddLine("including data already in the database.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    fullBtn:SetScript("OnLeave", GameTooltip_Hide)

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

    table.insert(output, EXPORT_PREFIX .. "\n")

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
-- Import Functions
-------------------------------------------------------------------------------

function ExportImport:ImportData(input)
    if not input or input == "" then
        HA.Addon:Print("No data to import.")
        return
    end
    
    -- Check version
    if not input:match("^HOMESTEAD_EXPORT_V1:") then
        HA.Addon:Print("Invalid or unsupported import format.")
        HA.Addon:Print("Expected format: HOMESTEAD_EXPORT_V1:...")
        return
    end
    
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
    
    HA.Addon:Print(string.format("Import complete: %d new, %d updated, %d skipped (older data).", 
        imported, updated, skipped))
    
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
-- Slash Command Integration
-------------------------------------------------------------------------------

-- These get registered in core.lua:
-- /hs export - calls ExportImport:ExportScannedVendors()
-- /hs import - calls ExportImport:ShowImportDialog()

-------------------------------------------------------------------------------
-- Module Registration
-------------------------------------------------------------------------------

if HA.Addon then
    HA.Addon:RegisterModule("ExportImport", ExportImport)
end
