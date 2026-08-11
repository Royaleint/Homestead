-- luacheck: globals assert loadfile print CreateFrame C_Timer C_Item C_Container hooksecurefunc ToggleBag OpenAllBags ToggleAllBags OpenBag BANK_CONTAINER ContainerFrameCombinedBags ContainerFrameContainer wipe

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Bag-open repaint stacking (Argus Major, follow-up to HS-283 sub-item D)
--
-- ToggleBag, OpenAllBags, ToggleAllBags, and OpenBag (added by HS-283 sub-item
-- D) each hooksecurefunc'd their own independent C_Timer.After(0.1,
-- HookAllContainers). One press of B routes through ToggleAllBags ->
-- OpenAllBagsInternal -> OpenBackpack() + an OpenBag(i) loop, so a single bag
-- open fires several of these hooks at once (hooksecurefunc fires even when
-- Blizzard's own body no-ops) and their identical 0.1s timers all expired on
-- the same frame -- several back-to-back full bag-overlay repaint passes for
-- one bag open. Proves:
--   (a) several hook fires within one "frame" (burst) schedule exactly ONE
--       C_Timer.After(0.1, ...) call, not one per fire (must-FAIL-if-broken:
--       reverting the coalescing makes this equal the fire count).
--   (b) that one timer firing runs HookAllContainers exactly once.
--   (c) a later burst, after the pending timer has fired and cleared, is not
--       swallowed -- it schedules and runs its own pass.
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

-- Unlike hs283_bag_overlay_drain's C_Timer stub (which fires immediately),
-- this test needs to observe how many timers get SCHEDULED during a burst
-- before any of them fire, so C_Timer.After here queues instead.
local scheduledTimers = {}
C_Timer = {
    After = function(delay, fn)
        table.insert(scheduledTimers, { delay = delay, fn = fn })
    end,
}

local function FireAllPending()
    local pending = scheduledTimers
    scheduledTimers = {}
    for _, timer in ipairs(pending) do
        timer.fn()
    end
end

-- Dummy Blizzard globals so Initialize()'s `if ToggleBag then ...` guards
-- pass and each gets hooksecurefunc'd.
ToggleBag = function() end
OpenAllBags = function() end
ToggleAllBags = function() end
OpenBag = function() end

local hookedCallbacks = {}
hooksecurefunc = function(name, fn)
    -- Only the four bare-function hook sites under test call hooksecurefunc
    -- with a string name; HookContainerFrame's per-button hook passes an
    -- (object, methodName, fn) triple instead and is irrelevant here (no
    -- container frames are ever hooked in this test).
    table.insert(hookedCallbacks, { name = name, fn = fn })
end

local hookAllContainersCalls = 0
local getChildrenCalls = 0
local function MakeContainerFrame()
    local frame = {}
    function frame:GetChildren()
        getChildrenCalls = getChildrenCalls + 1
    end
    return frame
end

ContainerFrameCombinedBags = nil
ContainerFrameContainer = { ContainerFrames = { MakeContainerFrame() } }

local HA = {
    Constants = { Overlay = { ICON_SIZE = 14 } },
    Addon = {
        db = { profile = { overlay = { enabled = true, showOnBags = true, showOnBank = true } } },
        RegisterModule = function() end,
        Debug = function()
            hookAllContainersCalls = hookAllContainersCalls + 1
        end,
    },
    Events = { RegisterCallback = function() end },
    Overlay = {
        AddToFrame = function(_, frame) return { frame = frame } end,
        ClearIcon = function() end,
        SetHomestoneState = function() end,
    },
    CatalogStore = { IsDecorItem = function() return false end },
    SourceManager = { GetInventoryItemStatus = function() return nil end },
}

assert(loadfile(root .. "/Overlay/Containers.lua"))("Homestead", HA)

-- Loading the file only queues C_Timer.After(0, Initialize) -- it doesn't run
-- Initialize() itself. Firing it registers the hooksecurefunc callbacks and
-- queues Initialize()'s own C_Timer.After(1, HookAllContainers); firing again
-- drains that one too, so both are gone before the assertions below start
-- from a clean slate. Neither run hits HA.Addon:Debug (the empty container
-- frame has no button to hook, and Debug only fires when hookedCount > 0).
FireAllPending()
FireAllPending()
assert(#scheduledTimers == 0, "setup must leave no timers pending before the burst assertions")
hookAllContainersCalls = 0
getChildrenCalls = 0

local function CallbacksFor(name)
    local matches = {}
    for _, entry in ipairs(hookedCallbacks) do
        if entry.name == name then table.insert(matches, entry.fn) end
    end
    return matches
end

local toggleAllBagsHook = CallbacksFor("ToggleAllBags")[1]
local openBagHook = CallbacksFor("OpenBag")[1]
local toggleBagHook = CallbacksFor("ToggleBag")[1]
local openAllBagsHook = CallbacksFor("OpenAllBags")[1]
assert(toggleAllBagsHook and openBagHook and toggleBagHook and openAllBagsHook,
    "all four Blizzard bag-open functions must be hooksecurefunc'd")

-------------------------------------------------------------------------------
-- (a) + (b): a single bag open (B key) fires ToggleAllBags once and OpenBag
-- several times (one per bag slot) in the same frame -- five hook fires total.
-- They must coalesce into exactly one scheduled timer, and firing it must run
-- HookAllContainers exactly once.
-------------------------------------------------------------------------------
toggleAllBagsHook()
openBagHook()
openBagHook()
openBagHook()
openBagHook()

assert(#scheduledTimers == 1,
    "a burst of 5 hook fires must coalesce into exactly one scheduled timer, got " .. #scheduledTimers)
assert(scheduledTimers[1].delay == 0.1, "the coalesced timer must keep the existing 0.1s delay")

FireAllPending()

assert(hookAllContainersCalls == 0,
    "the empty container frame has nothing to hook, so HA.Addon:Debug must not fire " ..
    "(getChildrenCalls is the real HookAllContainers-ran signal here)")
assert(getChildrenCalls == 1,
    "the one coalesced timer firing must run HookAllContainers exactly once, got " .. getChildrenCalls)

-------------------------------------------------------------------------------
-- (c) A later burst, after the pending flag has cleared, must schedule and
-- run its own pass -- the flag must not get stuck set.
-------------------------------------------------------------------------------
toggleBagHook()
openAllBagsHook()

assert(#scheduledTimers == 1,
    "a second, later burst must schedule its own timer once the first has cleared, got " ..
    #scheduledTimers)

FireAllPending()

assert(getChildrenCalls == 2,
    "the second burst's timer firing must run HookAllContainers again, got " .. getChildrenCalls)

print("hs283_bag_open_hook_coalesce: ok")
