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

local M = {}
HA.ProfessionOverlay = M

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
-- Index build (file load)
-------------------------------------------------------------------------------

BuildIndex()
