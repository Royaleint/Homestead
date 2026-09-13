-- luacheck: globals assert loadfile print pairs ipairs select setmetatable type
-- luacheck: globals wipe C_AddOns C_HousingCatalog GetLocale ScrollBoxListViewMixin
-- luacheck: globals HousingDashboardFrame

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-241 Gate 2 finding: the treasure badge never rendered because Blizzard's
-- static catalog presentation always resolves a vendor/profession badge first
-- for the same six items, and the static badge won unconditionally. The fix
-- ownership-gates priority: unowned + treasure-sourceText fallback wins over
-- the static badge; owned reverts to the static badge.
--
-- This pins both halves against the REAL Overlay/CatalogOverlay.lua and its
-- REAL ScrollBox/event wiring, the same technique hs_catalog_overlay_item_cache
-- uses: an item with BOTH a static vendor badge and a treasure sourceText
-- fallback must show treasure while unowned, then must actually switch to
-- vendor once OWNERSHIP_UPDATED fires -- not keep serving the stale cached
-- treasure verdict (the identical bug in reverse).
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

local TREASURE_SOURCE_TEXT = "Treasure: Gift of the Phoenix|nZone: Eversong Woods"

C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function()
        return { sourceText = TREASURE_SOURCE_TEXT }
    end,
}

-------------------------------------------------------------------------------
-- Frame stubs -- textures record the last atlas/visibility set on them so the
-- test can see which badge actually rendered, not just which one was computed.
-------------------------------------------------------------------------------

local function NewTexture()
    local tex = { shown = false }
    tex.SetSize = function() end
    tex.SetPoint = function() end
    tex.SetAllPoints = function() end
    tex.ClearAllPoints = function() end
    tex.SetAtlas = function(_, atlas) tex.atlas = atlas end
    tex.SetDesaturated = function() end
    tex.SetVertexColor = function() end
    tex.Show = function() tex.shown = true end
    tex.Hide = function() tex.shown = false end
    return tex
end

local function NewEntryFrame()
    local frame = { createdTextures = {} }
    frame.CreateTexture = function()
        local tex = NewTexture()
        table.insert(frame.createdTextures, tex)
        return tex
    end
    frame.SetAlpha = function() end
    frame.IsShown = function() return true end
    return frame
end

local capturedBindHandler, capturedBindOwner

local view = {
    RegisterCallback = function(_, event, fn, owner)
        assert(event == "OnInitializedFrame")
        capturedBindHandler, capturedBindOwner = fn, owner
    end,
}

local scrollBox = {
    GetView = function() return view end,
    GetChildren = function() end,
}

HousingDashboardFrame = {
    GetChildren = function() return scrollBox end,
    HookScript = function() end,
    IsShown = function() return true end,
}

-------------------------------------------------------------------------------
-- HA stub
-------------------------------------------------------------------------------

local Atlas = {
    vendor = "atlas-vendor",
    treasure = "atlas-treasure",
    profession = "atlas-profession",
    drop = "atlas-drop",
}

-- Ownership toggled mid-test to drive the second half of the pin.
local owned = false

local eventCallbacks = {}

local HA = {
    Constants = {
        SourceBadgeAtlas = Atlas,
    },
    Addon = { db = { profile = {} } },
    Events = {
        RegisterCallback = function(_, event, fn) eventCallbacks[event] = fn end,
    },
    Overlay = {
        RegisterExternalRefresher = function() end,
    },
    -- Models the real HS-241 shape: a static vendor badge is always resolvable
    -- (primarySourceBadgeAtlas), and catalogGlowState flips to "owned" once the
    -- player owns the item -- the exact signal the fix gates on.
    SourceManager = {
        GetItemPresentation = function()
            return {
                primarySourceBadgeAtlas = Atlas.vendor,
                catalogGlowState = owned and "owned" or "available",
            }
        end,
        NormalizeSourceType = function(_, sourceType) return sourceType end,
    },
    SourceTextParser = {
        ParseSourceText = function(_, text)
            if text == TREASURE_SOURCE_TEXT then
                return { sources = { { sourceType = "treasure" } } }
            end
            return { sources = { { sourceType = "vendor" } } }
        end,
    },
}

assert(loadfile(root .. "/Overlay/CatalogOverlay.lua"))("Homestead", HA)

assert(capturedBindHandler, "CatalogOverlay did not register an OnInitializedFrame handler")
assert(eventCallbacks["OWNERSHIP_UPDATED"], "OWNERSHIP_UPDATED callback not registered")

local function Bind(frame, itemID)
    frame.entryInfo = { itemID = itemID }
    capturedBindHandler(capturedBindOwner, frame, nil)
end

-------------------------------------------------------------------------------
-- 1. Unowned item with both a static vendor badge and a treasure sourceText
--    fallback must show the treasure badge, not the static one.
-------------------------------------------------------------------------------

local frame = NewEntryFrame()
Bind(frame, 9001)

local badgeTexture = frame.createdTextures[1]
assert(badgeTexture, "badge texture was never created")
assert(badgeTexture.atlas == Atlas.treasure,
    "unowned item with a treasure sourceText fallback must show the treasure badge over the static "
        .. "vendor badge (got " .. tostring(badgeTexture.atlas) .. ")")
assert(badgeTexture.shown == true, "treasure badge must be visible")

print("hs241_treasure_ownership_priority: unowned treasure fallback outranks static badge ok")

-------------------------------------------------------------------------------
-- 2. Ownership flips (OWNERSHIP_UPDATED) must invalidate itemVerdictCache and
--    re-resolve to the static vendor badge -- not keep serving the stale
--    cached treasure verdict from before the item was owned.
-------------------------------------------------------------------------------

owned = true
eventCallbacks["OWNERSHIP_UPDATED"]()

assert(badgeTexture.atlas == Atlas.vendor,
    "once owned, the static vendor badge must win again (got " .. tostring(badgeTexture.atlas)
        .. " -- a stale cached treasure verdict would leave the old atlas in place)")

print("hs241_treasure_ownership_priority: ownership flip re-resolves to the static badge ok")

-------------------------------------------------------------------------------
-- 3. A second bind of the same item (e.g. scroll recycling) after the flip
--    must keep serving the owned verdict, not fall back to a half-wiped cache.
-------------------------------------------------------------------------------

local frame2 = NewEntryFrame()
Bind(frame2, 9001)
local badgeTexture2 = frame2.createdTextures[1]
assert(badgeTexture2.atlas == Atlas.vendor,
    "a fresh frame bound to the now-owned item must resolve the vendor badge, not treasure")

print("hs241_treasure_ownership_priority: post-flip re-bind is consistent ok")
