--[[
    Homestead - ReagentIndex
    Reverse index from crafting reagent to the housing decor recipes that use it

    Built in memory each session from C_TradeSkillUI.GetRecipeSchematic for
    every recipe in HA.ProfessionSources, in small timer-driven chunks that
    pause during combat. Nothing is persisted.

    Learned state is read only from C_SpellBook.IsSpellKnown, at hover time,
    and is never stored. The trade skill recipe info's learned flag is not a
    usable source here: it reads false for every recipe until the player's
    own profession window loads, and afterwards follows whichever profession
    data (including a linked one) loaded last.
]]

local _, HA = ...

local ReagentIndex = {}
HA.ReagentIndex = ReagentIndex

local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local next = next
local error = error

local RECIPES_PER_CHUNK = 20
local TICK_DELAY = 0.01
local COMBAT_RETRY_DELAY = 1.0
local FALLBACK_DEBOUNCE = 1.0
-- Enum.CraftingReagentType.Basic; a nil reagentType is also a Basic slot.
local REAGENT_TYPE_BASIC = 1

-- reagentToDecor[reagentItemID] = { [decorItemID] = spellID }. Entries are
-- only ever added.
local reagentToDecor = {}
-- pending[spellID] = decorItemID for every recipe not yet fully read.
local pending = {}

local queue = {}
local queueCursor = 1
local queued = {}
local running = false
local initialized = false

-- Per-run bookkeeping for the run-complete debug line.
local runTrigger = nil
local runOps = 0
local runChunks = 0
local runCombatNoticed = false

local eventFrame = nil
local fallbackRegistered = false
local fallbackTimer = nil
local spellApiNoticeShown = false

local function DebugLine(message)
    if HA.DevAddon and HA.Addon.db.profile.debug then
        HA.Addon:Debug(message)
    end
end

local function Measured(operation, workload, callback, arg)
    local trace = HA.PerformanceTrace
    if trace then
        return trace:Measure(operation, workload, callback, arg)
    end
    return callback(arg)
end

-------------------------------------------------------------------------------
-- Prime
-------------------------------------------------------------------------------

local function IsCurrencySlot(slot)
    local slotTypes = Enum and Enum.TradeskillSlotDataType
    return slotTypes ~= nil and slot.dataSlotType == slotTypes.Currency
end

-- Reads one recipe's schematic and indexes every item of every Basic slot.
-- The recipe leaves `pending` only when it has at least one Basic slot and
-- every Basic slot named at least one item; otherwise the items it did read
-- stay indexed and a later fallback run reads it again.
local function PrimeRecipe(spellID)
    local decorItemID = pending[spellID]
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, spellID, false)
    if not (ok and schematic and schematic.reagentSlotSchematics) then return end

    local basicSlots, filledSlots = 0, 0
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local reagentType = slot.reagentType
        if (reagentType == nil or reagentType == REAGENT_TYPE_BASIC) and not IsCurrencySlot(slot) then
            basicSlots = basicSlots + 1
            local filled = false
            if slot.reagents then
                for _, reagent in ipairs(slot.reagents) do
                    local itemID = reagent.itemID
                    if itemID then
                        filled = true
                        local map = reagentToDecor[itemID]
                        if not map then
                            map = {}
                            reagentToDecor[itemID] = map
                        end
                        map[decorItemID] = spellID
                    end
                end
            end
            if filled then
                filledSlots = filledSlots + 1
            end
        end
    end

    if basicSlots > 0 and filledSlots == basicSlots then
        pending[spellID] = nil
    end
end

-- The cursor advances and `queued` clears before each read, so a read that
-- throws loses only itself and the next tick resumes after it.
local function ProcessChunk()
    local ops = 0
    while ops < RECIPES_PER_CHUNK and queueCursor <= #queue do
        local spellID = queue[queueCursor]
        queueCursor = queueCursor + 1
        queued[spellID] = nil
        if pending[spellID] then
            ops = ops + 1
            runOps = runOps + 1
            PrimeRecipe(spellID)
        end
    end
end

-------------------------------------------------------------------------------
-- Fallback: re-read unresolved recipes after trade skill list updates or a
-- loading screen, debounced, and only while something is still pending
-------------------------------------------------------------------------------

local Enqueue

local function OnFallbackExpired()
    fallbackTimer = nil
    for spellID in pairs(pending) do
        Enqueue(spellID, "fallback")
    end
end

local function OnFallbackEvent()
    if fallbackTimer then
        fallbackTimer:Cancel()
    end
    fallbackTimer = C_Timer.NewTimer(FALLBACK_DEBOUNCE, OnFallbackExpired)
end

local function UpdateFallbackRegistration()
    if next(pending) then
        if not fallbackRegistered then
            if not eventFrame then
                eventFrame = CreateFrame("Frame")
                eventFrame:SetScript("OnEvent", OnFallbackEvent)
            end
            eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
            eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            fallbackRegistered = true
        end
    elseif fallbackRegistered then
        eventFrame:UnregisterEvent("TRADE_SKILL_LIST_UPDATE")
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        fallbackRegistered = false
    end
end

-------------------------------------------------------------------------------
-- Worker
-------------------------------------------------------------------------------

local function CompleteRun()
    local pendingCount = 0
    for _ in pairs(pending) do
        pendingCount = pendingCount + 1
    end
    DebugLine(string.format("ReagentIndex: run complete: trigger=%s ops=%d chunks=%d pending=%d",
        runTrigger or "none", runOps, runChunks, pendingCount))

    wipe(queue)
    queueCursor = 1
    running = false
    runTrigger = nil
    runOps = 0
    runChunks = 0
    runCombatNoticed = false

    UpdateFallbackRegistration()
end

local function Tick()
    if InCombatLockdown() then
        if not runCombatNoticed then
            runCombatNoticed = true
            DebugLine("ReagentIndex: paused for combat")
        end
        C_Timer.After(COMBAT_RETRY_DELAY, Tick)
        return
    end

    runChunks = runChunks + 1
    local ok, err = pcall(Measured, "reagent_index_prime", runChunks, ProcessChunk)

    if queueCursor <= #queue then
        C_Timer.After(TICK_DELAY, Tick)
    else
        CompleteRun()
    end

    if not ok then
        DebugLine("ReagentIndex: chunk error, op dropped")
        error(err, 0)
    end
end

Enqueue = function(spellID, trigger)
    if queued[spellID] then return end
    queued[spellID] = true
    queue[#queue + 1] = spellID

    if runTrigger == nil then
        runTrigger = trigger
    elseif runTrigger ~= trigger then
        runTrigger = "mixed"
    end

    if not running then
        running = true
        C_Timer.After(TICK_DELAY, Tick)
    end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function ReagentIndex:Initialize()
    if initialized then return end
    initialized = true

    local sources = HA.ProfessionSources
    if not sources then return end
    for decorItemID, entry in pairs(sources) do
        if type(decorItemID) == "number" and type(entry) == "table" and entry.spellID then
            pending[entry.spellID] = decorItemID
            Enqueue(entry.spellID, "login")
        end
    end
end

-- Counts decor in `map` that are confirmed unowned and whose recipe the
-- spell book reports as known right now. Ownership is checked first: it is a
-- table read, and the spell book call is skipped for owned decor.
local function CountMissing(map)
    local isKnown = C_SpellBook and C_SpellBook.IsSpellKnown
    if not isKnown then
        if not spellApiNoticeShown then
            spellApiNoticeShown = true
            DebugLine("ReagentIndex: C_SpellBook.IsSpellKnown absent, reagent line off")
        end
        return 0
    end

    local store = HA.CatalogStore
    if not store then return 0 end

    -- Same readiness rule as CatalogStore:HasPersistedData: counts are only
    -- trusted once ownership is known, or storage confirmed a true zero.
    local ownedKnown = store:GetOwnedCount() > 0
    local scanner = HA.CatalogScanner
    local confirmedZero = not ownedKnown and scanner ~= nil
        and scanner:HasStorageResponded() and not scanner:IsWarm()
    if not (ownedKnown or confirmedZero) then return 0 end

    local count = 0
    for decorItemID, spellID in pairs(map) do
        local candidate
        if confirmedZero then
            candidate = true
        else
            local record = store:Get(decorItemID)
            candidate = record ~= nil and not record.isOwned
        end
        if candidate and isKnown(spellID) == true then
            count = count + 1
        end
    end
    return count
end

-- Number of learned, unowned decor recipes that use itemID as a Basic
-- reagent. Safe to call before Initialize (the index is empty).
function ReagentIndex:GetMissingDecorCount(itemID)
    local map = itemID and reagentToDecor[itemID]
    if not map then return 0 end
    return Measured("reagent_tooltip_count", itemID, CountMissing, map)
end
