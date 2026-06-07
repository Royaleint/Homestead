--[[
    Homestead - Catalog Detail-Pane Source Overlay

    Fills Blizzard's empty native "Source" line in the Housing Catalog detail
    pane (the 3D model preview) with Homestead's own source data, styled to
    match the native line. When Blizzard already shows a source, we show
    nothing (no duplication). Enhance-don't-replace: we reuse Blizzard's own
    reserved-but-hidden SourceInfo FontString slot rather than injecting a
    sibling.

    Trigger: hooksecurefunc on HousingModelPreviewMixin (not a WoW event).
    Load gate: Blizzard_HousingModelPreview (LoadOnDemand; loads independently
    of the dashboard via the chat-link path).

    See: Home_Dev/plans/active/HS-113-catalog-detail-source.md
]]

local _, HA = ...

local CatalogDetailSource = {}
HA.CatalogDetailSource = CatalogDetailSource

-- Idempotent hook-registration guard (process lifetime).
local registered = false

-------------------------------------------------------------------------------
-- itemID resolution (decorID/recordID -> itemID)
-------------------------------------------------------------------------------

-- Resolve the catalog entry's itemID. The preview's catalogEntryInfo is NOT
-- guaranteed to carry itemID (Blizzard's preview code only reads recordID), so
-- we bridge via GetCatalogEntryInfoByRecordID. Cached on the preview frame,
-- keyed by recordID, so dye-variant cycles of the same entry cost zero API
-- calls. The negative result is cached too (avoids re-pcall on dataless items).
function CatalogDetailSource:ResolveItemID(preview, recordID)
    if preview.homesteadResolvedRecordID == recordID and preview.homesteadResolvedItemID ~= nil then
        return preview.homesteadResolvedItemID
    end

    local itemID = nil

    -- Opportunistic: use itemID if the table happens to carry one (free).
    if type(preview.catalogEntryInfo.itemID) == "number" then
        itemID = preview.catalogEntryInfo.itemID
    elseif recordID and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID then
        -- Robust path: recordID -> itemID. Tainted-but-works (high confidence).
        local ok, byRec = pcall(C_HousingCatalog.GetCatalogEntryInfoByRecordID, 1, recordID, true)
        if ok and byRec then
            itemID = byRec.itemID
        end
    end

    preview.homesteadResolvedRecordID = recordID
    preview.homesteadResolvedItemID = itemID -- may be nil; cache the negative
    return itemID
end

-------------------------------------------------------------------------------
-- Source line builder
-------------------------------------------------------------------------------

-- Build a compact, single-block source string for the detail pane.
-- Mirrors the source priority + label vocabulary used by Overlay/Tooltips.lua:
--   1. GetBestAvailableSource (first source not known to be blocked)
--   2. fall back to GetAllSources()[1] (show known data even if blocked now)
--   3. nil -> caller leaves the slot hidden
-- Uses |n newlines (cap ~3 lines) to stay within the single SourceInfo slot.
-- Returns the string, or nil when there is genuinely no data.
function CatalogDetailSource:BuildSourceLine(itemID)
    if not itemID or not HA.SourceManager then
        return nil
    end

    local primary = HA.SourceManager:GetBestAvailableSource(itemID)
    if not primary then
        -- best-available is nil when sources exist but are all currently
        -- blocked; fall back to the first known source so we don't hide data.
        local all = HA.SourceManager:GetAllSources(itemID)
        primary = all and all[1]
    end
    if not primary then
        return nil
    end

    local data = primary.data
    if not data then
        return nil
    end

    local t = primary.type

    if t == "vendor" then
        local line = "Vendor: " .. (data.name or "Unknown Vendor")
        if data.zone then
            line = line .. "|nZone: " .. data.zone
        end
        if data.cost and HA.VendorData then
            local cost = HA.VendorData:FormatCost(data.cost)
            if cost then
                line = line .. "|nCost: " .. cost
            end
        end
        return line

    elseif t == "quest" then
        local line = "Quest: " .. (data.questName or "Unknown Quest")
        if data.zone then
            line = line .. "|nZone: " .. data.zone
        end
        return line

    elseif t == "achievement" then
        return "Achievement: " .. (data.achievementName or "Unknown Achievement")

    elseif t == "profession" then
        local prof = data.skillTier or data.profession or "Unknown"
        if data.skillLevel then
            prof = prof .. " (" .. data.skillLevel .. ")"
        end
        return "Profession: " .. prof

    elseif t == "event" then
        local line = "Event: " .. (data.event or "Unknown Event")
        if data.zone then
            line = line .. "|nZone: " .. data.zone
        end
        return line

    elseif t == "drop" then
        local line = "Drop: " .. (data.mobName or "Unknown")
        if data.zone then
            line = line .. "|nZone: " .. data.zone
        end
        return line

    elseif t == "shop" then
        return "Shop: " .. (data.name or "In-Game Shop")
    end

    return nil
end

-------------------------------------------------------------------------------
-- Hook handlers
-------------------------------------------------------------------------------

-- Post-hook on HousingModelPreviewMixin:ApplyCurrentVariant. We only ever
-- SetText/Show SourceInfo in the (base-variant AND native-source-empty) branch.
-- In every other branch we leave the FontString exactly as Blizzard set it
-- (Blizzard re-runs SetTextOrHide on SourceInfo at the top of every fire,
-- before this post-hook), so we never stomp Blizzard's line or leave stale
-- text.
function CatalogDetailSource:OnVariantApplied(preview)
    -- Live toggle read (no /reload needed). Default true.
    local db = HA.Addon and HA.Addon.db and HA.Addon.db.profile
    if db and db.tooltip and db.tooltip.showDetailSource == false then
        return
    end

    local info = preview.catalogEntryInfo
    if not info or (preview.HasValidData and not preview:HasValidData()) then
        return
    end

    -- Base variant = no variantInfo, or the base variant identifier (0).
    local isBaseVariant = (not preview.variantInfo)
        or (preview.variantInfo.entryVariantID
            and preview.variantInfo.entryVariantID.variantIdentifier == 0)

    -- Dyed (non-base) variant: Blizzard hides SourceInfo by design; match it.
    if not isBaseVariant then
        return
    end

    -- Native source present (exactly Blizzard's L213 predicate): Blizzard has
    -- already shown SourceInfo with its own text. Do not overwrite.
    if info.sourceText and info.sourceText ~= "" then
        return
    end

    -- Native is empty on the base variant -> this is our gap to fill.
    local recordID = info.recordID
    if not recordID then
        return
    end

    local itemID = self:ResolveItemID(preview, recordID)
    if not itemID then
        return -- leave SourceInfo hidden (Blizzard already hid it)
    end

    local text = self:BuildSourceLine(itemID)
    if not text then
        return -- no data -> leave hidden (Blizzard already hid it)
    end

    local container = preview.TextContainer
    if not container or not container.SourceInfo then
        return
    end

    container.SourceInfo:SetText(text)
    container.SourceInfo:Show()
    -- Reflow the vertical stack so CollectionBonus/NumOwned reposition beneath
    -- our now-shown slot. Layout() is an unprotected, idempotent display op.
    if container.Layout then
        container:Layout()
    end
end

-- ClearPreviewData nils catalogEntryInfo (catalog hide / standalone close).
-- Clear our per-frame cache so a reopened pane re-resolves cleanly. No need to
-- hide SourceInfo: ApplyCurrentVariant SetTextOrHide's it on next show.
function CatalogDetailSource:OnPreviewCleared(preview)
    preview.homesteadResolvedRecordID = nil
    preview.homesteadResolvedItemID = nil
end

-------------------------------------------------------------------------------
-- Hook registration (deferred to Blizzard_HousingModelPreview load)
-------------------------------------------------------------------------------

local function RegisterHooks()
    if registered then return end
    registered = true

    hooksecurefunc(_G.HousingModelPreviewMixin, "ApplyCurrentVariant", function(preview)
        CatalogDetailSource:OnVariantApplied(preview)
    end)
    hooksecurefunc(_G.HousingModelPreviewMixin, "ClearPreviewData", function(preview)
        CatalogDetailSource:OnPreviewCleared(preview)
    end)
end

-- Blizzard_HousingModelPreview is LoadOnDemand and loads independently of the
-- dashboard (e.g. via a chat decor-link). Gate on it, not the dashboard.
if C_AddOns.IsAddOnLoaded("Blizzard_HousingModelPreview") then
    RegisterHooks()
else
    _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingModelPreview", RegisterHooks)
end
