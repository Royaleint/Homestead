--[[
    Homestead - Container Overlays
    Overlays for bags and bank frames
]]

local _, HA = ...

local Overlay = HA.Overlay
local Events = HA.Events
local CatalogStore = HA.CatalogStore
local SourceManager = HA.SourceManager

-- Local state
local containerButtons = {}

-------------------------------------------------------------------------------
-- Bag Item Update Function
-------------------------------------------------------------------------------

local function GetButtonItemLink(button)
    if not button then
        return nil
    end

    if button.GetItemLocation and C_Item and C_Item.GetItemLink then
        local itemLocation = button:GetItemLocation()
        if itemLocation and itemLocation.IsValid and itemLocation:IsValid() then
            local itemLink = C_Item.GetItemLink(itemLocation)
            if itemLink then
                return itemLink
            end
        end
    end

    local bag = nil
    if button.GetBagID then
        bag = button:GetBagID()
    end
    if bag == nil then
        bag = button.bagID
    end
    if bag == nil and button.GetParent and button:GetParent() then
        bag = button:GetParent():GetID()
    end

    local slot = nil
    if button.GetID then
        slot = button:GetID()
    end
    if slot == nil then
        slot = button.slotIndex or button.slot
    end

    if bag and slot then
        return C_Container.GetContainerItemLink(bag, slot)
    end

    return nil
end

local function GetButtonBagID(button)
    if not button then return nil end

    if button.GetBagID then
        local bagID = button:GetBagID()
        if bagID ~= nil then
            return bagID
        end
    end
    if button.bagID ~= nil then
        return button.bagID
    end
    if button.GetParent and button:GetParent() then
        return button:GetParent():GetID()
    end

    return nil
end

local function IsBankBagID(bagID)
    if bagID == BANK_CONTAINER then
        return true
    end
    if type(bagID) ~= "number" or not Enum or not Enum.BagIndex then
        return false
    end

    local bagIndex = Enum.BagIndex
    local characterBankMain = bagIndex.Characterbanktab or bagIndex.CharacterBank
    return bagID == bagIndex.Bank
        or bagID == bagIndex.Reagentbank
        or bagID == bagIndex.BankBag_1
        or bagID == bagIndex.BankBag_2
        or bagID == bagIndex.BankBag_3
        or bagID == bagIndex.BankBag_4
        or bagID == bagIndex.BankBag_5
        or bagID == bagIndex.BankBag_6
        or bagID == bagIndex.BankBag_7
        or (characterBankMain and bagID == characterBankMain)
        or bagID == bagIndex.CharacterBankTab_1
        or bagID == bagIndex.CharacterBankTab_2
        or bagID == bagIndex.CharacterBankTab_3
        or bagID == bagIndex.CharacterBankTab_4
        or bagID == bagIndex.CharacterBankTab_5
        or bagID == bagIndex.CharacterBankTab_6
        or bagID == bagIndex.AccountBankTab_1
        or bagID == bagIndex.AccountBankTab_2
        or bagID == bagIndex.AccountBankTab_3
        or bagID == bagIndex.AccountBankTab_4
        or bagID == bagIndex.AccountBankTab_5
end

local function IsContextEnabled(button, isBankButton)
    local profile = HA.Addon and HA.Addon.db and HA.Addon.db.profile
    local settings = profile and profile.overlay
    if not settings or not settings.enabled then
        return false
    end

    if isBankButton then
        return settings.showOnBank
    end

    local bagID = GetButtonBagID(button)
    if bagID == nil then
        return settings.showOnBags or settings.showOnBank
    end
    if IsBankBagID(bagID) then
        return settings.showOnBank
    end

    return settings.showOnBags
end

local function SetInventoryHomestone(overlay, itemLink)
    if not overlay then return end

    if not CatalogStore or not SourceManager or not itemLink then
        Overlay:ClearIcon(overlay)
        return
    end

    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not CatalogStore:IsDecorItem(itemLink) then
        Overlay:ClearIcon(overlay)
        return
    end

    local status = SourceManager:GetInventoryItemStatus(itemID)
    Overlay:SetHomestoneState(overlay, status)
    if overlay.icon then
        overlay.icon:Hide()
        overlay.icon:SetTexture(nil)
    end
end

local function IsLikelyItemButton(frame)
    if not frame then
        return false
    end
    if frame.GetItemLocation or frame.GetBagID then
        return true
    end
    if type(frame.SetItemButtonTexture) == "function" then
        return true
    end
    return false
end

-- HS-204(e): hoisted to file scope + a reused result table (CatalogOverlay's
-- ProcessChildren pattern) instead of allocating a fresh {buttons, seen} pair
-- plus two closures every call. HookContainerFrame (the only caller) reads
-- the result synchronously within the same call and never retains it, so
-- reuse is safe; wipe() at the top of each call keeps a previous container's
-- buttons from leaking into the next.
local collectedButtons = {}
local seenButtons = {}

local function AddCollectedButton(button)
    if not button or seenButtons[button] then
        return
    end
    seenButtons[button] = true
    table.insert(collectedButtons, button)
end

-- Fallback: traverse children to support frame variants where Items is absent
local function ProcessContainerChildren(depth, ...)
    if depth > 4 then return end
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if IsLikelyItemButton(child) then
            AddCollectedButton(child)
        end
        ProcessContainerChildren(depth + 1, child:GetChildren())
    end
end

local function CollectContainerButtons(containerFrame)
    wipe(collectedButtons)
    wipe(seenButtons)

    local items = containerFrame and containerFrame.Items
    if type(items) == "table" then
        for _, button in pairs(items) do
            if IsLikelyItemButton(button) then
                AddCollectedButton(button)
            end
        end
    end

    if containerFrame then
        ProcessContainerChildren(1, containerFrame:GetChildren())
    end

    return collectedButtons
end

local function UpdateContainerButton(button)
    if not button then return end

    local overlay = button.HousingAddonOverlay
    if not overlay then
        overlay = Overlay:AddToFrame(button, function()
            UpdateContainerButton(button)
        end)
    end

    if not overlay then return end

    -- HS-283: the single choke point every update path funnels through
    -- (HookContainerFrame's already-hooked branch, the hook-time immediate
    -- paint above via Overlay:AddToFrame, and UpdateAllContainerOverlays) --
    -- skip the context/item-link/catalog-probe work for a currently-invisible
    -- button. The overlay is still created/attached above regardless of
    -- visibility, so this button's own OnShow hook (below, in
    -- HookContainerFrame) repaints it correctly once it becomes visible
    -- again -- this skip is a deferral, not a staleness risk.
    if not button:IsVisible() then
        return
    end

    if not IsContextEnabled(button) then
        Overlay:ClearIcon(overlay)
        return
    end

    local itemLink = GetButtonItemLink(button)

    SetInventoryHomestone(overlay, itemLink)
end

-------------------------------------------------------------------------------
-- Container Frame Hooking
-------------------------------------------------------------------------------

local function HookContainerFrame(containerFrame)
    if not containerFrame then return end

    local hookedCount = 0

    local items = CollectContainerButtons(containerFrame)
    for _, button in ipairs(items) do
        if not button.HousingAddonHooked then
            table.insert(containerButtons, button)

            -- Create overlay
            Overlay:AddToFrame(button, function()
                UpdateContainerButton(button)
            end)

            button:HookScript("OnShow", function(self)
                UpdateContainerButton(self)
            end)

            if type(button.SetItemButtonTexture) == "function" then
                hooksecurefunc(button, "SetItemButtonTexture", function(self)
                    -- Delay slightly to ensure item data is available
                    C_Timer.After(0, function()
                        UpdateContainerButton(self)
                    end)
                end)
            end

            button.HousingAddonHooked = true
            hookedCount = hookedCount + 1
        else
            UpdateContainerButton(button)
        end
    end

    return hookedCount
end

local function HookAllContainers()
    local hookedCount = 0

    -- Hook combined bags frame
    local combinedBags = ContainerFrameCombinedBags
    if combinedBags then
        hookedCount = hookedCount + (HookContainerFrame(combinedBags) or 0)
    end

    -- Hook individual bag frames
    local frameContainer = ContainerFrameContainer
    if frameContainer and frameContainer.ContainerFrames then
        for _, bagFrame in ipairs(frameContainer.ContainerFrames) do
            hookedCount = hookedCount + (HookContainerFrame(bagFrame) or 0)
        end
    end

    if hookedCount > 0 then
        HA.Addon:Debug("Container frames hooked", hookedCount)
    end
end

-- One bag open can hooksecurefunc-trigger several of the Blizzard functions
-- below on the same frame (see the Initialize() comment). This flag coalesces
-- their independent 0.1s timers into a single HookAllContainers pass: the
-- first call in a burst schedules the timer and sets the flag, every other
-- call in the same burst is a no-op, and the timer clears the flag on fire so
-- the next burst schedules its own pass.
local hookAllPending = false

local function ScheduleHookAllContainers()
    if hookAllPending then
        return
    end
    hookAllPending = true
    C_Timer.After(0.1, function()
        hookAllPending = false
        HookAllContainers()
    end)
end

-------------------------------------------------------------------------------
-- Bank Frame Hooking
-------------------------------------------------------------------------------

local function HookBankFrame()
    -- Hook bank slots when bank opens
    -- Note: Bank UI structure may vary, this is a general approach

    local bankFrame = BankFrame
    if not bankFrame then return end

    -- Hook bank item buttons
    for i = 1, NUM_BANKGENERIC_SLOTS or 28 do
        local button = _G["BankFrameItem" .. i]
        if button and not button.HousingAddonHooked then
            Overlay:AddToFrame(button, function(overlay)
                if not IsContextEnabled(button, true) then
                    Overlay:ClearIcon(overlay)
                    return
                end

                local itemLink = C_Container.GetContainerItemLink(BANK_CONTAINER, i)
                SetInventoryHomestone(overlay, itemLink)
            end)
            button.HousingAddonHooked = true -- luacheck: ignore 122
        end
    end

    HA.Addon:Debug("Bank frame hooked")
end

-------------------------------------------------------------------------------
-- Update Functions
-------------------------------------------------------------------------------

local function UpdateAllContainerOverlays()
    for _, button in ipairs(containerButtons) do
        UpdateContainerButton(button)
    end
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

-- HS-283: true if any bag container frame is currently shown. Checks exactly
-- the same frame universe HookAllContainers() hooks from (combined bags +
-- every frame in ContainerFrameContainer.ContainerFrames, which also covers
-- bank/reagent bank/warband bank tabs -- confirmed via Blizzard UI source,
-- ContainerFrame_IsBankTab is checked alongside ContainerFrame_IsHeldBag
-- throughout the same file that owns ContainerFrameContainer.ContainerFrames)
-- -- mirrors Blizzard's own hide-skips-work discipline without needing to
-- hook per-frame OnHide/OnShow ourselves.
local function IsAnyContainerFrameVisible()
    local combinedBags = ContainerFrameCombinedBags
    if combinedBags and combinedBags:IsShown() then
        return true
    end

    local frameContainer = ContainerFrameContainer
    if frameContainer and frameContainer.ContainerFrames then
        for _, bagFrame in ipairs(frameContainer.ContainerFrames) do
            if bagFrame:IsShown() then
                return true
            end
        end
    end

    return false
end

local function OnBagUpdate()
    -- HS-283: skip the traversal entirely when nothing is open -- the
    -- per-loot-event cost this event previously paid unconditionally.
    if not IsAnyContainerFrameVisible() then
        return
    end

    -- Frames can be rebuilt dynamically; re-scan hook targets then refresh.
    -- HS-283: no separate UpdateAllContainerOverlays() call here anymore --
    -- HookAllContainers()'s own traversal (HookContainerFrame's else-branch,
    -- for already-hooked buttons) already updates every currently-collected
    -- button on this pass; a second full pass over containerButtons was a
    -- pure duplicate for this call site. OnBankOpened() and the
    -- ToggleBag/OpenAllBags/ToggleAllBags hooksecurefunc sites are
    -- deliberately left untouched -- see the plan's design notes.
    HookAllContainers()
end

local function OnBankOpened()
    HookBankFrame()
    UpdateAllContainerOverlays()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function Initialize()
    -- Register callbacks. Ownership rule (HS-209): this module OWNS the "bags"
    -- update type — requested from core.lua's OnBagUpdate (BAG_UPDATE_DELAYED)
    -- and consumed here. Overlay/overlay.lua deliberately registers no "bags"
    -- callback; cross-surface repaints arrive via "all"/OWNERSHIP_UPDATED.
    Events:RegisterCallback("bags", OnBagUpdate)

    -- Hook Blizzard functions. A single bag open can route through several of
    -- these at once -- e.g. pressing B fires ToggleAllBags -> OpenBackpack()
    -- plus an OpenBag(i) loop, so ToggleAllBags and OpenBag both fire on the
    -- same press -- and hooksecurefunc fires even when Blizzard's own body
    -- no-ops. Without coalescing, each hook scheduled its own independent
    -- 0.1s timer, and 3-6 identical HookAllContainers passes landed on the
    -- same frame. hookAllPending gates all of them down to one pass per burst.
    if ToggleBag then
        hooksecurefunc("ToggleBag", ScheduleHookAllContainers)
    end

    if OpenAllBags then
        hooksecurefunc("OpenAllBags", ScheduleHookAllContainers)
    end

    if ToggleAllBags then
        hooksecurefunc("ToggleAllBags", ScheduleHookAllContainers)
    end

    -- HS-283 (review finding): ToggleBackpack (combined-bags mode) and
    -- OpenAllBagsMatchingContext (the item-upgrade/keystone/soulbinds
    -- auto-open) both bypass the three hooks above, routing through OpenBag
    -- directly (ContainerFrame.lua:272) -- without this hook, a bag opened
    -- only via one of those paths would show no overlays until the next
    -- bag-content change while open. Same shape as the other three.
    if OpenBag then
        hooksecurefunc("OpenBag", ScheduleHookAllContainers)
    end

    -- Register for bank events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BANKFRAME_OPENED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" then
            OnBankOpened()
        end
    end)

    -- Initial hook attempt (in case bags are already open)
    C_Timer.After(1, HookAllContainers)

    HA.Addon:Debug("Container overlay module initialized")
end

-- Initialize when addon loads
if HA.Addon then
    -- Delay initialization to ensure other modules are ready
    C_Timer.After(0, Initialize)
else
    -- Fallback: Initialize on PLAYER_LOGIN
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", Initialize)
end
