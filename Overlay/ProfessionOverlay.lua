--[[
    Homestead - Profession Window Décor Overlay (HS-024 Phase 1)

    Ambiently badges Blizzard's Professions recipe-list rows that produce
    housing décor the player CAN craft (recipe LEARNED and craftable now) and
    does NOT yet own. Absence is the signal — no badge on owned, unlearned,
    not-craftable, or non-décor rows. No new UI window; this enhances
    Blizzard's own Professions frame (Apple method).

    Smart filter (HS-075, absorbed; HS-024 Rev-2 "can craft" = learned +
    craftable-now per Rawb) — a row badges iff:
      1. recipeID resolves to a known décor item (ResolveDecorForRecipe), AND
      2. the player can craft it now — read from the row's own recipeInfo
         (node:GetData().recipeInfo), ZERO extra C calls:
           recipeInfo.learned == true  AND  recipeInfo.craftable == true.
         `learned == true` subsumes the old profession+skillTier check (a
         recipe can only be learned if the player has the profession and met
         the tier), so SourceManager:IsSourceAvailableNow is no longer called
         on the hot path (HS-024 Rev-2 #1/#3 — kills the per-row allocation in
         PlayerMeetsSkillLevel). `craftable == true` is Blizzard's own
         can-make-it-now flag (Blizzard_ProfessionsCrafting.lua:570 gates on
         `not craftable or disabled`). AND
      3. the player does not own the output: not CatalogStore:IsOwned(itemID)
         (cache-only on the hot path — IsOwnedFresh is reserved for the
          bounded window-open reconcile, never the per-Init path).

    Hook strategy (Gate 0, in-game verified 2026-06-05 via /hsdev recipespike):
    post-hook hooksecurefunc(ProfessionsRecipeListRecipeMixin, "Init", handler).
    Fires per recipe row per recycle. recipeInfo via node:GetData().recipeInfo
    (Init path) — Blizzard_ProfessionsRecipeList.lua:237-241 reads learned from
    exactly this; we thread that same recipeInfo through to gate the badge.
    recipeID == recipeInfo.recipeID == ProfessionSources.spellID (verified four
    ways, 1:1 reverse map). Live-row repaint reads recipeInfo via
    frame:GetElementData().data.recipeInfo (the .data FIELD — verified vs
    Blizzard_ProfessionsRecipeList.lua:353-354), distinct from the Init node's
    :GetData() METHOD (HS-024 Rev-2 #2).

    Taint: the row is ProfessionsRecipeListRecipeTemplate, a plain virtual
    <Button> (not Secure/Protected). We parent an unmanaged Texture and only
    Show/Hide/SetTexture/SetPoint our own region. We never mutate the row's
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

-- Badge: the Homestead house icon (Textures/HomesteadMinimap) — the recognizable
-- brand mark from the mockup — chosen over the catalog's profession source-type
-- glyph for visibility/recognizability on the recipe row (Gate-2 decision, Rawb
-- 2026-06-05; the catalog overlay keeps its profession glyph). The recipe row is
-- ~20px tall, so the badge stays compact. RIGHT inset — the LEFT gutter is
-- Blizzard's SkillUps indicator, which we must never overlap or mutate.
local BADGE_TEXTURE = "Interface\\AddOns\\Homestead\\Textures\\HomesteadMinimap"
local BADGE_SIZE = 18
local BADGE_INSET = -3

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
-- `recipeInfo` is the row's own recipeInfo table (node:GetData().recipeInfo on
-- the Init path, GetElementData().data.recipeInfo on the live-repaint path);
-- both expose recipeID, learned, and craftable. Returns shouldBadge (bool),
-- itemID, entry. Smart-filter short-circuit order (HS-024 Rev-2):
--   1. resolves to décor (else no badge)
--   2. can craft now: recipeInfo.learned == true AND recipeInfo.craftable == true
--      — read straight off the row's recipeInfo, ZERO extra C calls. `learned`
--      subsumes the old profession+skillTier gate, so IsSourceAvailableNow (and
--      its PlayerMeetsSkillLevel allocation) is no longer on the hot path.
--   3. doesn't own output: not IsOwned(itemID) — cache-only
function M:ShouldBadgeRecipe(recipeInfo)
    local recipeID = recipeInfo and recipeInfo.recipeID
    local itemID, entry = self:ResolveDecorForRecipe(recipeID)
    if not itemID then
        return false
    end

    -- Can craft now? "can craft" = learned + craftable-now (Rawb, HS-024 Rev-2).
    -- Both flags live on the row's recipeInfo already in hand (no C call). An
    -- unlearned recipe (Blizzard still renders it as an Init-firing row) or one
    -- not currently craftable (missing reagents / wrong context) does not badge.
    if recipeInfo.learned ~= true or recipeInfo.craftable ~= true then
        return false, itemID, entry
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
    badge:SetTexture(BADGE_TEXTURE)
    badge.isHomesteadProfBadge = true  -- tag for /hsdev professiondiag detection
    badge:Hide()
    badgeTextures[rowButton] = badge
    return badge
end

-------------------------------------------------------------------------------
-- Recipe-row hook (post-hook on the list mixin's Init)
-------------------------------------------------------------------------------

-- Pull the recipeInfo out of an Init node's element data, defensively.
-- Init's node is the tree element; recipe rows expose GetData().recipeInfo
-- (verified Blizzard_ProfessionsRecipeList.lua:237 — `local elementData =
-- node:GetData()` then reads `elementData.recipeInfo.learned`). Headers/dividers
-- use a different element shape, so a nil here = not a recipe row. We return the
-- whole recipeInfo (not a bare recipeID) so ShouldBadgeRecipe can read its
-- learned/craftable flags with zero extra C calls (HS-024 Rev-2 #1).
local function ResolveNodeRecipeInfo(node)
    if not node or type(node.GetData) ~= "function" then return nil end
    local data = node:GetData()
    return data and data.recipeInfo
end

-- Recompute show/hide for one realized recipe row Button against its recipeInfo.
-- Recycle-safe: called every Init, no per-row persistent state beyond the
-- weak-cached texture; the show/hide decision is recomputed from scratch.
local function EvaluateRow(rowButton, recipeInfo)
    if not recipeInfo then
        -- Not a recipe row (or recipeInfo unavailable): ensure any stale badge
        -- from a prior occupant of this recycled frame is hidden.
        local existing = badgeTextures[rowButton]
        if existing then existing:Hide() end
        return
    end
    GetBadge(rowButton):SetShown(M:ShouldBadgeRecipe(recipeInfo))
end

-- Post-hook handler installed on ProfessionsRecipeListRecipeMixin.Init.
-- `self` is the recipe row Button; `node` is Init's first real param.
-- Wrapped in pcall so one malformed row can't error the entire list redraw.
local function OnRecipeRowInit(self, node)
    if not self then return end
    local ok, err = pcall(function()
        EvaluateRow(self, ResolveNodeRecipeInfo(node))
    end)
    if not ok and HA.Addon and HA.Addon.Debug then
        HA.Addon:Debug("ProfessionOverlay: row Init handler error:", tostring(err))
    end
end

local hookInstalled = false

-- Forward declaration: the window-open reconcile lives in the freshness section
-- below but is referenced by InstallHook's OnShow handler.
local RepaintVisibleRows

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

    -- One-shot bounded IsOwnedFresh reconcile on each window open: catches décor
    -- already owned at open time (cache may be stale before the first scan). The
    -- subsequent EvaluateRow uses the now-warm cache, so this stays off the
    -- per-Init hot path. Guarded so a missing frame can't error.
    local frame = _G and _G.ProfessionsFrame
    if frame and frame.HookScript then
        frame:HookScript("OnShow", function()
            RepaintVisibleRows(true)
        end)
    end
end

-------------------------------------------------------------------------------
-- Freshness: live-row re-evaluation + window-open reconcile
-------------------------------------------------------------------------------

-- Dirty flag: set when ownership/source data changes while the window is closed
-- (or not scrolled). Consumed by the window-open reconcile and naturally cleared
-- as Init refires on the next open/scroll.
M.needsRepaint = false

-- Resolve the live ProfessionsFrame recipe-list ScrollBox, defensively.
-- Returns the ScrollBox or nil if the frame isn't built/shown.
local function GetRecipeScrollBox()
    local frame = _G and _G.ProfessionsFrame
    if not frame or not frame:IsShown() then return nil end
    local craftingPage = frame.CraftingPage
    local recipeList = craftingPage and craftingPage.RecipeList
    local scrollBox = recipeList and recipeList.ScrollBox
    if not scrollBox or type(scrollBox.GetFrames) ~= "function" then return nil end
    return scrollBox
end

-- Resolve a realized row frame's recipeInfo. A LIVE ScrollBox row frame exposes
-- GetElementData(), whose result wraps the tree node — the recipeInfo lives on
-- the .data FIELD of that result (frame:GetElementData().data.recipeInfo), NOT
-- via a :GetData() method. Verified vs Blizzard source: the row mixin's own
-- OnEnter reads exactly `self:GetElementData().data.recipeInfo.recipeID`
-- (Blizzard_ProfessionsRecipeList.lua:353-354). This is a DIFFERENT shape from
-- the Init node (which is the raw node, accessed via node:GetData()), so the
-- repaint path needs its own accessor — reusing the Init-node accessor here
-- silently no-ops the stationary-window repaint (HS-024 Rev-2 #2).
-- GetFrames() returns a mixed-template list (categories/dividers too), so a nil
-- here = a non-recipe frame the caller must skip.
local function ResolveFrameRecipeInfo(frame)
    if not frame or type(frame.GetElementData) ~= "function" then return nil end
    local elementData = frame:GetElementData()
    local data = elementData and elementData.data
    return data and data.recipeInfo
end

-- Re-evaluate every currently realized recipe row in place. Handles the
-- stationary-window case (a craft/learn/purchase with the window open and no
-- scroll) that the Init hook alone misses; the every-Init recompute remains the
-- backstop for scrolled rows. Optionally runs a bounded IsOwnedFresh reconcile
-- (used once on window open to catch décor already owned at open time).
RepaintVisibleRows = function(reconcileFresh)
    local scrollBox = GetRecipeScrollBox()
    if not scrollBox then return end

    local frames = scrollBox:GetFrames()
    local store = HA.CatalogStore

    -- Fix #4: the window-open reconcile runs IsOwnedFresh over every visible
    -- décor row; each successful probe writes ownership through and would fire
    -- its own OWNERSHIP_UPDATED, re-entering Repaint per row — an O(visible²)
    -- cascade. Wrap the whole reconcile pass in a batch so it fires at most one
    -- trailing OWNERSHIP_UPDATED (CatalogStore contract: "always wrap bulk
    -- operations"). Guarded + pcall'd so a missing or throwing batch API can't
    -- leave the store stuck in batch mode.
    local batched = reconcileFresh and store and store.BeginBatch and store.EndBatch
    if batched then
        pcall(store.BeginBatch, store)
    end

    for _, frame in ipairs(frames) do
        local recipeInfo = ResolveFrameRecipeInfo(frame)
        if recipeInfo then
            -- Bounded fresh reconcile: only on window open, only for rows that
            -- resolve to décor, and only the live probe (no per-scroll storm).
            if reconcileFresh then
                local itemID = M:ResolveDecorForRecipe(recipeInfo.recipeID)
                if itemID and store and store.IsOwnedFresh then
                    store:IsOwnedFresh(itemID)  -- writes ownership through on success
                end
            end
            EvaluateRow(frame, recipeInfo)
        else
            EvaluateRow(frame, nil)  -- hide any stale badge on a non-recipe row
        end
    end

    if batched then
        pcall(store.EndBatch, store)  -- fires at most one trailing OWNERSHIP_UPDATED
    end

    M.needsRepaint = false
end

-- Inter-module repaint on ownership/source change. SourceManager owns the single
-- WoW event frame and fires these custom events; we only repaint — no duplicate
-- WoW event registration (CLAUDE.md rule #1). Sets the dirty flag for the
-- window-closed case and, if the window is open, re-evaluates live rows now.
local function Repaint()
    M.needsRepaint = true
    RepaintVisibleRows(false)
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

-------------------------------------------------------------------------------
-- Event-driven repaint (no new WoW event frame — inter-module only)
-------------------------------------------------------------------------------

-- OWNERSHIP_UPDATED fires when a décor is acquired/removed; SOURCE_CACHES_INVALIDATED
-- fires when profession/availability caches change (SourceManager owns the single
-- WoW event frame). We only repaint — no duplicate WoW event registration.
if HA.Events then
    HA.Events:RegisterCallback("OWNERSHIP_UPDATED", Repaint)
    HA.Events:RegisterCallback("SOURCE_CACHES_INVALIDATED", Repaint)
end

-- Let Overlay:RefreshAll() also drive profession-window badges.
if HA.Overlay then
    HA.Overlay:RegisterExternalRefresher("professionBadges", Repaint)
end
