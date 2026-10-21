--[[
    Homestead - Dev Geography Diagnostics (HS-537)

    Dev-only home for the /hs debug geography and /hs debug vertical commands
    and the report builders behind them, split out of Core/core.lua,
    Core/constants.lua and UI/MapPinProvider.lua so the player addon does not
    carry them. This file is never listed in Homestead.toc and is excluded from
    the packaged zip (.pkgmeta); the DevBuild TOC loads it after the modules it
    extends. It reads only public tables on MapPinProvider and Constants.

    Command registration waits for PLAYER_LOGIN, by which point core.lua's
    OnInitialize has run and HousingAddon.commands exists (see
    Core/DevMemoryDiagnostics.lua).
]]

local _, HA = ...

local HousingAddon = HA.Addon
local Constants = HA.Constants
local MapPinProvider = HA.MapPinProvider
local format = string.format

local function AddManualGeographyAuditRow(rows, tableName, sourceMapID, viewMapID, nativeOk, nativeReason, manualReason)
    local status = nativeOk and "manual_redundant_candidate" or "manual_required"
    rows[#rows + 1] = {
        tableName = tableName,
        sourceMapID = sourceMapID,
        viewMapID = viewMapID,
        nativeStatus = nativeOk and "native_ok" or "native_failed",
        status = status,
        nativeReason = nativeReason,
        manualReason = manualReason,
    }
end

function MapPinProvider:GetManualGeographyAuditReport()
    local rows = {}
    local summary = {
        checked = 0,
        manualRequired = 0,
        redundantCandidates = 0,
    }

    for continentMapID in pairs(self.offWorldContinentPositions or {}) do
        local nativeOk, _, _, nativeReason = self:ProjectMapPositionToAncestorView(continentMapID, 947, 0.5, 0.5)
        AddManualGeographyAuditRow(
            rows,
            "offWorldContinentPositions",
            continentMapID,
            947,
            nativeOk,
            nativeReason,
            "manual_continent_position"
        )
    end

    for zoneMapID, parentPositions in pairs(self.manualZoneCenters or {}) do
        for parentMapID in pairs(parentPositions) do
            local nativeOk, _, _, nativeReason = self:ProjectMapPositionToAncestorView(zoneMapID, parentMapID, 0.5, 0.5)
            AddManualGeographyAuditRow(
                rows,
                "manualZoneCenters",
                zoneMapID,
                parentMapID,
                nativeOk,
                nativeReason,
                "manual_zone_center"
            )
        end
    end

    table.sort(rows, function(a, b)
        if a.tableName ~= b.tableName then
            return a.tableName < b.tableName
        end
        if a.sourceMapID ~= b.sourceMapID then
            return a.sourceMapID < b.sourceMapID
        end
        return a.viewMapID < b.viewMapID
    end)

    summary.checked = #rows
    for _, row in ipairs(rows) do
        if row.status == "manual_redundant_candidate" then
            summary.redundantCandidates = summary.redundantCandidates + 1
        elseif row.status == "manual_required" then
            summary.manualRequired = summary.manualRequired + 1
        end
    end

    return {
        rows = rows,
        summary = summary,
    }
end

function Constants.GetVerticalSiblingsInfo()
    local seen, lines = {}, {}
    for mapID, targets in pairs(Constants.VerticalSiblings) do
        for targetID, direction in pairs(targets) do
            local pairKey = mapID < targetID
                and (mapID .. ":" .. targetID)
                or (targetID .. ":" .. mapID)
            if not seen[pairKey] then
                seen[pairKey] = true
                local infoA = C_Map.GetMapInfo(mapID)
                local infoB = C_Map.GetMapInfo(targetID)
                local nameA = infoA and infoA.name or tostring(mapID)
                local nameB = infoB and infoB.name or tostring(targetID)
                local arrow = direction == "below" and "above" or "below"
                lines[#lines + 1] = string.format(
                    "%d (%s) is %s %d (%s)",
                    mapID, nameA, arrow, targetID, nameB
                )
            end
        end
    end
    return lines
end

function HousingAddon:PrintManualGeographyAuditReport()
    local MPP = HA.MapPinProvider
    if not MPP or not MPP.GetManualGeographyAuditReport then
        self:Print("MapPinProvider audit is not available.")
        return
    end

    local report = MPP:GetManualGeographyAuditReport()
    local summary = report and report.summary or {}
    self:Print(format(
        "Manual geography audit: %d checked, %d required, %d redundant candidates",
        summary.checked or 0,
        summary.manualRequired or 0,
        summary.redundantCandidates or 0
    ))

    if not report or not report.rows or #report.rows == 0 then
        return
    end

    for _, row in ipairs(report.rows) do
        self:Print(format(
            "  %s %s->%s: %s (%s; native=%s)",
            row.tableName or "?",
            tostring(row.sourceMapID),
            tostring(row.viewMapID),
            row.status or "?",
            row.manualReason or "?",
            row.nativeReason or "unknown"
        ))
    end
end

local devGeoFrame = CreateFrame("Frame")
devGeoFrame:RegisterEvent("PLAYER_LOGIN")
devGeoFrame:SetScript("OnEvent", function()
    HousingAddon.commands:Register({ name = "debug vertical",
        help = "Print vertical-sibling info.",
        handler = function()
            local lines = Constants.GetVerticalSiblingsInfo()
            HousingAddon:Print("VerticalSiblings (" .. #lines .. " pairs):")
            for _, line in ipairs(lines) do
                HousingAddon:Print("  " .. line)
            end
        end })
    HousingAddon.commands:Register({ name = "debug geography",
        help = "Audit manual map geography entries.",
        handler = function() HousingAddon:PrintManualGeographyAuditReport() end })
end)
