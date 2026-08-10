-- luacheck: globals assert loadfile print CreateFrame C_Timer C_Item C_Container BANK_CONTAINER NUM_BANKGENERIC_SLOTS ContainerFrameCombinedBags ContainerFrameContainer wipe

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-283 sub-item D: Overlay/Containers.lua bag-overlay drain
--
-- Before this fix: OnBagUpdate() (fired on every loot event, BAG_UPDATE_DELAYED,
-- 0.2s-throttled) ran a full, unguarded traversal-and-update pass regardless of
-- whether any bag was open, and updated every already-hooked button TWICE per
-- fire (once via HookContainerFrame's already-hooked branch, once more via a
-- second full pass over containerButtons). Proves:
--   (a) nothing shown -> OnBagUpdate does zero traversal/paint work.
--   (b) a visible, already-hooked button is painted exactly once per fire, not
--       twice (must-FAIL-if-broken: reverting the dedup makes this 2).
--   (c) on that SAME fire, a hidden button (its container isn't shown) is
--       painted zero times -- the skip lives in UpdateContainerButton, the
--       real hot-path choke point, not in UpdateAllContainerOverlays (which
--       OnBagUpdate no longer calls at all).
--   (d) a button that becomes visible again repaints via its own OnShow hook,
--       closing the gap (c) opens.
-------------------------------------------------------------------------------

wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(handler, fn) self.scripts[handler] = fn end
    return frame
end

C_Timer = { After = function(_, fn) fn() end }

local containerItemLinkCalls = {}
local function CallsFor(bagID, slot)
    return containerItemLinkCalls[bagID .. ":" .. slot] or 0
end

C_Container = {
    GetContainerItemLink = function(bagID, slot)
        local key = bagID .. ":" .. slot
        containerItemLinkCalls[key] = (containerItemLinkCalls[key] or 0) + 1
        return "item:12345"
    end,
}

C_Item = {
    GetItemInfoInstant = function() return 12345 end,
}

-- Two container frames: one will be shown, one stays hidden throughout the
-- steady-state test, so a single OnBagUpdate fire exercises both the
-- visible-button (paint) and hidden-button (skip) paths at once.
--
-- getChildrenCalls (HS-283 Gate 1 finding): the per-button IsVisible skip
-- alone zeroes out paint-call observables even if the TOP-LEVEL
-- IsAnyContainerFrameVisible() guard is deleted -- CollectContainerButtons's
-- GetChildren() fallback still runs regardless in that broken scenario, so
-- counting these calls is what actually proves the guard, not just the
-- per-button skip, is what's silencing case (a).
local getChildrenCalls = 0
local function MakeContainerFrame()
    local frame = { Items = {}, shown = false }
    function frame:IsShown() return frame.shown end
    function frame:GetChildren()
        getChildrenCalls = getChildrenCalls + 1
    end
    return frame
end

local function MakeButton(bagID, slot)
    local button = { visible = false, showScripts = {} }
    function button:GetBagID() return bagID end
    function button:GetID() return slot end
    function button:IsVisible() return button.visible end
    function button:HookScript(event, fn) button.showScripts[event] = fn end
    return button
end

local shownFrame = MakeContainerFrame()
local hiddenFrame = MakeContainerFrame()
local V = MakeButton(0, 1)  -- lives in shownFrame, becomes visible
local H = MakeButton(1, 1)  -- lives in hiddenFrame, stays hidden
shownFrame.Items[1] = V
hiddenFrame.Items[1] = H

ContainerFrameCombinedBags = nil
ContainerFrameContainer = { ContainerFrames = { shownFrame, hiddenFrame } }

local bagsCallback = nil

local HA = {
    Constants = { Overlay = { ICON_SIZE = 14 } },
    Addon = {
        db = { profile = { overlay = { enabled = true, showOnBags = true, showOnBank = true } } },
        RegisterModule = function() end,
        Debug = function() end,
    },
    Events = {
        RegisterCallback = function(_, name, fn)
            if name == "bags" then bagsCallback = fn end
        end,
    },
    Overlay = {
        AddToFrame = function(_, frame, updateFunc)
            local overlay = { frame = frame }
            frame.HousingAddonOverlay = overlay
            if updateFunc then updateFunc(overlay) end
            return overlay
        end,
        ClearIcon = function() end,
        SetHomestoneState = function() end,
    },
    CatalogStore = { IsDecorItem = function() return false end },
    SourceManager = { GetInventoryItemStatus = function() return nil end },
}

assert(loadfile(root .. "/Overlay/Containers.lua"))("Homestead", HA)

local OnBagUpdate = bagsCallback
assert(OnBagUpdate, "the \"bags\" callback must have been registered during Initialize()")

-- Initialize()'s own deferred C_Timer.After(1, HookAllContainers) already ran
-- synchronously above (both frames hidden, both buttons invisible at that
-- point) -- both V and H are already hooked. Reset call counts to start the
-- real assertions from a clean baseline.
containerItemLinkCalls = {}
getChildrenCalls = 0

-------------------------------------------------------------------------------
-- (a) Nothing shown -- OnBagUpdate must do zero traversal/paint work. The
-- getChildrenCalls check specifically proves the TOP-LEVEL
-- IsAnyContainerFrameVisible() guard is what's skipping this, not just the
-- per-button IsVisible skip (which alone wouldn't stop the traversal itself).
-------------------------------------------------------------------------------
shownFrame.shown = false
hiddenFrame.shown = false
OnBagUpdate()
assert(getChildrenCalls == 0,
    "OnBagUpdate with nothing shown must not even traverse container frames (top-level guard)")
assert(CallsFor(0, 1) == 0 and CallsFor(1, 1) == 0,
    "OnBagUpdate with nothing shown must do no paint work at all")

-------------------------------------------------------------------------------
-- (b) + (c): shownFrame becomes visible, its button becomes visible. One
-- fire must paint V exactly once (not twice) and H zero times.
-------------------------------------------------------------------------------
shownFrame.shown = true
V.visible = true
-- hiddenFrame / H stay hidden/invisible.

OnBagUpdate()
assert(getChildrenCalls > 0,
    "OnBagUpdate with something shown must actually traverse container frames")
assert(CallsFor(0, 1) == 1,
    "a visible, already-hooked button must be painted exactly once per OnBagUpdate fire, not twice")
assert(CallsFor(1, 1) == 0,
    "a hidden button must receive zero paint work on the same fire")

-------------------------------------------------------------------------------
-- (d) H becomes visible -- its own OnShow hook must repaint it, closing the
-- gap the skip in (c) opened.
-------------------------------------------------------------------------------
H.visible = true
assert(H.showScripts.OnShow, "a hooked button must have an OnShow script captured")
H.showScripts.OnShow(H)
assert(CallsFor(1, 1) == 1, "a button becoming visible must repaint via its own OnShow hook")

print("hs283_bag_overlay_drain: ok")
