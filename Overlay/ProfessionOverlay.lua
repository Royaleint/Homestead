--[[
    Homestead - Profession Window Décor Overlay (HS-024 Phase 1)

    Ambiently badges Blizzard's Professions recipe-list rows that produce
    housing décor the player CAN craft (profession known AND skill tier met)
    and does NOT yet own. Absence is the signal — no badge on owned,
    not-craftable, or non-décor rows. No new UI window; this enhances
    Blizzard's own Professions frame (Apple method).

    Smart filter (HS-075, absorbed) — a row badges iff:
      1. recipeID resolves to a known décor item (ResolveDecorForRecipe), AND
      2. the player can craft it now:
         SourceManager:IsSourceAvailableNow(itemID, {type='profession', data=entry}) ~= false
         (~=false, NOT ==true: Miscellaneous / skill-less décor returns nil → allow;
          an untrained tier returns false → block), AND
      3. the player does not own the output: not CatalogStore:IsOwned(itemID)
         (cache-only on the hot path — IsOwnedFresh is reserved for the
          bounded window-open reconcile, never the per-Init path).

    Hook strategy (Gate 0, in-game verified 2026-06-05 via /hsdev recipespike):
    post-hook hooksecurefunc(ProfessionsRecipeListRecipeMixin, "Init", handler).
    Fires per recipe row per recycle. recipeID via node:GetData().recipeInfo.recipeID.
    recipeID == ProfessionSources.spellID (verified four ways, 1:1 reverse map).

    Taint: the row is ProfessionsRecipeListRecipeTemplate, a plain virtual
    <Button> (not Secure/Protected). We parent an unmanaged Texture and only
    Show/Hide/SetAtlas/SetPoint our own region. We never mutate the row's
    Label / Count / SkillUps / LockedIcon, and the badge is NOT added to Init's
    rightFrames table (which drives Label width math), so it cannot truncate
    recipe names. Reads only; no selectionBehavior / SetDataProvider / craft-button
    touch. Works in combat (not a protected mutation).

    Pattern-B self-initializing module: Blizzard_Professions is load-on-demand,
    so an OnEnable Initialize chain would gain nothing — install is deferred via
    EventUtil.ContinueOnAddOnLoaded.
]]

local _, HA = ...

local Constants = HA.Constants
local SourceBadgeAtlas = Constants and Constants.SourceBadgeAtlas

local M = {}
HA.ProfessionOverlay = M

-- Badge sizing: the recipe row is ~20px tall, so we use a compact icon (NOT the
-- 30px catalog-grid override). RIGHT inset — the LEFT gutter is Blizzard's
-- SkillUps indicator, which we must never overlap or mutate.
local BADGE_SIZE = 16
local BADGE_INSET = -2

-- Lazy weak-keyed (__mode='k') badge Texture per recipe row Button. Weak keys
-- let Blizzard's frame pool reclaim row frames without us pinning them.
local badgeTextures = setmetatable({}, { __mode = "k" })

-- Reverse map: recipe spellID → décor entry. Built once at file load from the
-- static HA.ProfessionSources table (308 entries). Stores the full entry (not a
-- bare itemID) so the craftability gate and Phases 2/3 get profession/skillTier
-- for free.  spellToEntry[spellID] = { itemID = <catalog itemID>, entry = <source entry> }
local spellToEntry = {}

-------------------------------------------------------------------------------
-- Reverse-map builder
-------------------------------------------------------------------------------

-- Invert HA.ProfessionSources (keyed by itemID) into spellToEntry (keyed by
-- spellID).  One O(n) pass at file load — static data, no runtime rebuild.
-- Dup-tolerant: first-write-wins + dev-log on collision (1:1 verified this
-- session; the builder degrades to one un-badged item + a dev note rather than
-- erroring if a future pipeline regeneration introduces a duplicate spellID).
local function BuildIndex()
    local sources = HA.ProfessionSources
    if type(sources) ~= "table" then
        if HA.Addon and HA.Addon.Debug then
            HA.Addon:Debug("ProfessionOverlay: ProfessionSources missing or not a table; no recipes indexed")
        end
        return
    end

    local count = 0
    for itemID, entry in pairs(sources) do
        local spellID = entry and entry.spellID
        if spellID then
            local existing = spellToEntry[spellID]
            if existing then
                if HA.Addon and HA.Addon.Debug then
                    HA.Addon:Debug("ProfessionOverlay: duplicate spellID", spellID,
                        "- keeping itemID", existing.itemID, "ignoring", itemID)
                end
            else
                spellToEntry[spellID] = { itemID = itemID, entry = entry }
                count = count + 1
            end
        end
    end

    if count == 0 and HA.Addon and HA.Addon.Debug then
        HA.Addon:Debug("ProfessionOverlay: indexed 0 décor recipes (empty source table?)")
    end
end

-------------------------------------------------------------------------------
-- Public resolvers (Phase 2/3 reuse ResolveDecorForRecipe)
-------------------------------------------------------------------------------

-- Resolve a recipe's spellID to its décor output.
-- Returns itemID, entry — or nil when the recipe is not a known décor recipe.
function M:ResolveDecorForRecipe(recipeID)
    if not recipeID then return nil end
    local mapped = spellToEntry[recipeID]
    if not mapped then return nil end
    return mapped.itemID, mapped.entry
end

-- Predicate: should this recipe row carry the décor badge?
-- Returns shouldBadge (bool), itemID, entry.  Smart-filter short-circuit order:
--   1. resolves to décor (else no badge)
--   2. can craft now: IsSourceAvailableNow(...) ~= false
--   3. doesn't own output: not IsOwned(itemID) — cache-only
function M:ShouldBadgeRecipe(recipeID)
    local itemID, entry = self:ResolveDecorForRecipe(recipeID)
    if not itemID then
        return false
    end

    -- Can craft now? ~=false is load-bearing (see file header). A nil result
    -- (Miscellaneous / skill-less) is treated as craftable; only an explicit
    -- false (wrong profession / untrained tier) blocks the badge.
    local sm = HA.SourceManager
    if sm and sm.IsSourceAvailableNow then
        local available = sm:IsSourceAvailableNow(itemID, { type = "profession", data = entry })
        if available == false then
            return false, itemID, entry
        end
    end

    -- Already owned? Cache-only on the hot path (IsOwnedFresh is reserved for
    -- the bounded window-open reconcile in Commit 3).
    local store = HA.CatalogStore
    if store and store.IsOwned and store:IsOwned(itemID) then
        return false, itemID, entry
    end

    return true, itemID, entry
end

-------------------------------------------------------------------------------
-- Badge texture (lazy create-once, weak-cached per row)
-------------------------------------------------------------------------------

-- Create or retrieve the unmanaged badge Texture for a recipe row Button.
-- Parented to the row, OVERLAY layer, unnamed (allowlist stays at 8). The badge
-- is intentionally NOT added to Init's rightFrames table, so it stays outside
-- Blizzard's Label width math and cannot truncate recipe names.
local function GetBadge(rowButton)
    local badge = badgeTextures[rowButton]
    if badge then return badge end

    badge = rowButton:CreateTexture(nil, "OVERLAY")
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    badge:SetPoint("RIGHT", rowButton, "RIGHT", BADGE_INSET, 0)
    if SourceBadgeAtlas and SourceBadgeAtlas.profession then
        badge:SetAtlas(SourceBadgeAtlas.profession, false)
    end
    badge:Hide()
    badgeTextures[rowButton] = badge
    return badge
end

-------------------------------------------------------------------------------
-- Recipe-row hook (post-hook on the list mixin's Init)
-------------------------------------------------------------------------------

-- Pull the recipeID out of a recipe row's element data, defensively.
-- Init's node is the tree element; recipe rows expose GetData().recipeInfo.recipeID.
-- Headers/dividers use a different element shape, so a nil here = not a recipe row.
local function ResolveRowRecipeID(node)
    if not node or type(node.GetData) ~= "function" then return nil end
    local data = node:GetData()
    local recipeInfo = data and data.recipeInfo
    return recipeInfo and recipeInfo.recipeID
end

-- Recompute show/hide for one realized recipe row Button against its recipeID.
-- Recycle-safe: called every Init, no per-row persistent state beyond the
-- weak-cached texture; the show/hide decision is recomputed from scratch.
local function EvaluateRow(rowButton, recipeID)
    if not recipeID then
        -- Not a recipe row (or recipeID unavailable): ensure any stale badge from
        -- a prior occupant of this recycled frame is hidden.
        local existing = badgeTextures[rowButton]
        if existing then existing:Hide() end
        return
    end
    GetBadge(rowButton):SetShown(M:ShouldBadgeRecipe(recipeID))
end

-- Post-hook handler installed on ProfessionsRecipeListRecipeMixin.Init.
-- `self` is the recipe row Button; `node` is Init's first real param.
-- Wrapped in pcall so one malformed row can't error the entire list redraw.
local function OnRecipeRowInit(self, node)
    if not self then return end
    local ok, err = pcall(function()
        EvaluateRow(self, ResolveRowRecipeID(node))
    end)
    if not ok and HA.Addon and HA.Addon.Debug then
        HA.Addon:Debug("ProfessionOverlay: row Init handler error:", tostring(err))
    end
end

local hookInstalled = false

-- Install the post-hook on the recipe-list row mixin. Idempotent and
-- drift-guarded: if Blizzard renames/restructures the mixin or its Init, we
-- dev-warn and bail (fail-loud-on-drift) rather than nil-hooking. Deferred until
-- Blizzard_Professions (load-on-demand) is present.
local function InstallHook()
    if hookInstalled then return end

    local mixin = _G and _G.ProfessionsRecipeListRecipeMixin
    if type(mixin) ~= "table" or type(mixin.Init) ~= "function" then
        if HA.Addon and HA.Addon.Debug then
            HA.Addon:Debug("ProfessionOverlay: ProfessionsRecipeListRecipeMixin.Init missing - API drift, badge disabled")
        end
        return
    end

    hooksecurefunc(mixin, "Init", OnRecipeRowInit)
    hookInstalled = true
end

-------------------------------------------------------------------------------
-- Index build (file load) + deferred hook install
-------------------------------------------------------------------------------

BuildIndex()

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
    InstallHook()
else
    local eventUtil = _G and _G.EventUtil
    if eventUtil and eventUtil.ContinueOnAddOnLoaded then
        eventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", InstallHook)
    end
end
