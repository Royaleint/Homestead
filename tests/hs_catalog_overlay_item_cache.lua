-- luacheck: globals assert loadfile print pairs ipairs select setmetatable type
-- luacheck: globals wipe C_AddOns C_HousingCatalog GetLocale ScrollBoxListViewMixin
-- luacheck: globals HousingDashboardFrame

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- CatalogOverlay's itemID-keyed verdict cache.
--
-- The ScrollBox OnInitializedFrame handler that replaced the 5Hz poll fires
-- once per pooled-frame REBIND (1742 times on one fast full scroll). The
-- pre-existing overlayCache is keyed by frame, so every one of those rebinds
-- is a miss and re-runs the whole expensive resolve inside the scroll frame:
-- C_HousingCatalog.GetCatalogEntryInfoByItem, SourceManager:GetItemPresentation
-- and SourceTextParser:ParseSourceText. The fix memoizes the resolved verdict
-- by itemID behind the frame cache.
--
-- Both halves of the mechanism are pinned here, because either one alone is
-- worse than no change: a cache that never invalidates trades scroll frame
-- time for permanently stale badges. The observable is the CALL COUNT into
-- each of the three expensive functions, not whether UpdateEntryOverlay ran --
-- it runs on every bind either way, so a test that only checked that would
-- pass with the cache deleted.
--
-- Loads the REAL Overlay/CatalogOverlay.lua and drives it through the REAL
-- ScrollBox callback it registers, and the REAL HA.Events callbacks it
-- subscribes, rather than extracting functions.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- WoW globals the file touches at load and on the paths under test
-------------------------------------------------------------------------------

wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

GetLocale = function() return "enUS" end

ScrollBoxListViewMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } }

C_AddOns = {
    IsAddOnLoaded = function(name) return name == "Blizzard_HousingDashboard" end,
}

-- Call counters for the three expensive resolves. A cache hit must not
-- increment any of them.
local apiCalls, presentationCalls, parseCalls = 0, 0, 0

C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function()
        apiCalls = apiCalls + 1
        return { sourceText = "Sold by a test vendor" }
    end,
}

-------------------------------------------------------------------------------
-- Frame stubs
-------------------------------------------------------------------------------

local function NewTexture()
    return {
        SetSize = function() end,
        SetPoint = function() end,
        SetAllPoints = function() end,
        ClearAllPoints = function() end,
        SetAtlas = function() end,
        SetDesaturated = function() end,
        SetVertexColor = function() end,
        Show = function() end,
        Hide = function() end,
    }
end

local function NewEntryFrame()
    return {
        CreateTexture = function() return NewTexture() end,
        SetAlpha = function() end,
        IsShown = function() return true end,
    }
end

-- The dashboard tree CatalogOverlay walks looking for ScrollBox views:
-- dashboard -> scrollBox (exposes :GetView()) -> view.
local capturedBindHandler, capturedBindOwner

local view = {
    RegisterCallback = function(_, event, fn, owner)
        assert(event == "OnInitializedFrame",
            "expected the overlay to register on OnInitializedFrame, got " .. tostring(event))
        capturedBindHandler, capturedBindOwner = fn, owner
    end,
}

local scrollBox = {
    GetView = function() return view end,
    GetChildren = function() end,
}

-- Shown at load, so CatalogOverlay takes its already-open branch: it
-- discovers the ScrollBox and marks the dashboard visible without the test
-- needing to drive the OnShow hook.
HousingDashboardFrame = {
    GetChildren = function() return scrollBox end,
    HookScript = function() end,
    IsShown = function() return true end,
}

-------------------------------------------------------------------------------
-- HA stub
-------------------------------------------------------------------------------

local eventCallbacks = {}

local HA = {
    Constants = {
        -- profession/drop are read at file scope for ATLAS_SIZE_OVERRIDE,
        -- so they must be present even though this test badges a vendor item.
        SourceBadgeAtlas = {
            vendor = "atlas-vendor",
            shop = "atlas-shop",
            profession = "atlas-profession",
            drop = "atlas-drop",
        },
    },
    Addon = { db = { profile = {} } },
    Events = {
        RegisterCallback = function(_, event, fn) eventCallbacks[event] = fn end,
    },
    Overlay = {
        RegisterExternalRefresher = function() end,
    },
    -- Returns a presentation carrying neither a badge atlas nor a glow state,
    -- so the resolve falls through to the sourceText parser and all three
    -- expensive calls run exactly once per miss. (Returning nil instead would
    -- retrigger the `presentation or GetCatalogPresentation(itemID)` fallback
    -- in GetSourceBadgeAtlas/GetAccessibilityState; real items always get a
    -- table back, so a nil here would measure a path that does not occur.)
    SourceManager = {
        GetItemPresentation = function()
            presentationCalls = presentationCalls + 1
            return {}
        end,
        NormalizeSourceType = function(_, sourceType) return sourceType end,
    },
    SourceTextParser = {
        ParseSourceText = function()
            parseCalls = parseCalls + 1
            return { sources = { { sourceType = "vendor" } } }
        end,
    },
}

assert(loadfile(root .. "/Overlay/CatalogOverlay.lua"))("Homestead", HA)

assert(capturedBindHandler, "CatalogOverlay did not register an OnInitializedFrame handler")
assert(eventCallbacks["SOURCE_CACHES_INVALIDATED"], "SOURCE_CACHES_INVALIDATED callback not registered")
assert(eventCallbacks["OWNERSHIP_UPDATED"], "OWNERSHIP_UPDATED callback not registered")

-- Simulate Blizzard binding a pooled entry frame to a catalog item.
-- entryInfo deliberately carries no sourceText, so the resolve takes the
-- GetCatalogEntryInfoByItem fallback the way it does in game.
local function Bind(frame, itemID)
    frame.entryInfo = { itemID = itemID }
    capturedBindHandler(capturedBindOwner, frame, nil)
end

local frameA, frameB, frameC = NewEntryFrame(), NewEntryFrame(), NewEntryFrame()

-------------------------------------------------------------------------------
-- 1. A rebind to an already-evaluated itemID must not recompute.
-------------------------------------------------------------------------------

Bind(frameA, 501)
assert(presentationCalls == 1 and apiCalls == 1 and parseCalls == 1,
    "first bind of an item must resolve it once (got presentation=" .. presentationCalls
        .. " api=" .. apiCalls .. " parse=" .. parseCalls .. ")")

-- A DIFFERENT pooled frame bound to the SAME item -- exactly what scrolling
-- does. The frame-keyed overlayCache misses here; the itemID cache must catch it.
Bind(frameB, 501)
assert(presentationCalls == 1 and apiCalls == 1 and parseCalls == 1,
    "rebinding a previously-evaluated itemID onto another pooled frame must be a cache hit, "
        .. "not a re-resolve (got presentation=" .. presentationCalls
        .. " api=" .. apiCalls .. " parse=" .. parseCalls .. ")")

print("hs_catalog_overlay_item_cache: pooled-frame rebind is a cache hit ok")

-------------------------------------------------------------------------------
-- 2. Invalidation must reach the itemID cache too, or badges go stale forever.
--
-- The catalog is open, so each event repaints the two frames known so far:
-- the first recomputes item 501, the second hits the freshly refilled cache.
-- Exactly +1 per event. Without wipe(itemVerdictCache) the repaint would hit
-- the stale entry and the count would not move at all.
-------------------------------------------------------------------------------

eventCallbacks["SOURCE_CACHES_INVALIDATED"]()
assert(presentationCalls == 2 and apiCalls == 2 and parseCalls == 2,
    "SOURCE_CACHES_INVALIDATED must force the next evaluation to re-resolve (got presentation="
        .. presentationCalls .. " api=" .. apiCalls .. " parse=" .. parseCalls .. ")")

eventCallbacks["OWNERSHIP_UPDATED"]()
assert(presentationCalls == 3 and apiCalls == 3 and parseCalls == 3,
    "OWNERSHIP_UPDATED must force the next evaluation to re-resolve (got presentation="
        .. presentationCalls .. " api=" .. apiCalls .. " parse=" .. parseCalls .. ")")

print("hs_catalog_overlay_item_cache: SOURCE_CACHES_INVALIDATED + OWNERSHIP_UPDATED invalidate ok")

-------------------------------------------------------------------------------
-- 3. The cache is refilled by the post-invalidation repaint, and it is keyed
--    per item -- a genuinely new item still resolves.
-------------------------------------------------------------------------------

Bind(frameC, 501)
assert(presentationCalls == 3,
    "after invalidation the repaint refills the cache; a further bind of the same item must hit it")

Bind(frameA, 777)
assert(presentationCalls == 4 and apiCalls == 4 and parseCalls == 4,
    "a bind of an item never evaluated before must still resolve (the cache must be per-item)")

print("hs_catalog_overlay_item_cache: per-item keying ok")

-------------------------------------------------------------------------------
-- 4. Vendor-scan source discovery must invalidate too (Argus cycle 1 CRITICAL).
--
-- A merchant scan wipes SourceManager's source memo through the deliberately
-- broadcast-free InvalidateSourcesMemo, so it fires VENDOR_SCANNED and nothing
-- else. Unsubscribed, an item cached as "no known source" before the scan
-- keeps that verdict -- no badge, no glow -- until some unrelated invalidation
-- happens along, where the pre-cache recompute-per-bind behaviour self-healed.
--
-- Three frames are known by now, bound to two DISTINCT items (777 and 501), so
-- the repaint resolves exactly twice regardless of pairs() order: the first
-- frame per item computes, the rest hit the refilled cache.
-------------------------------------------------------------------------------

assert(eventCallbacks["VENDOR_SCANNED"],
    "CatalogOverlay must subscribe VENDOR_SCANNED -- vendor-scan source discovery "
        .. "reaches no other invalidation path this file listens to")

eventCallbacks["VENDOR_SCANNED"]({ hasDecor = true }, false)
assert(presentationCalls == 6 and apiCalls == 6 and parseCalls == 6,
    "VENDOR_SCANNED must force the next evaluation to re-resolve (got presentation="
        .. presentationCalls .. " api=" .. apiCalls .. " parse=" .. parseCalls .. ")")

print("hs_catalog_overlay_item_cache: VENDOR_SCANNED invalidates ok")
