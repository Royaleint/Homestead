--[[
    Homestead - Container Overlays
    Overlays for bags and bank frames
]]

local _, HA = ...

-- Wait for Overlay module
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

local function CollectContainerButtons(containerFrame)
    local buttons = {}
    local seen = {}

    local function AddButton(button)
        if not button or seen[button] then
            return
        end
        seen[button] = true
        table.insert(buttons, button)
    end

    local items = containerFrame and containerFrame.Items
    if type(items) == "table" then
        for _, button in pairs(items) do
            if IsLikelyItemButton(button) then
                AddButton(button)
            end
        end
    end

    -- Fallback: traverse children to support frame variants where Items is absent
    local function ProcessContainerChildren(depth, ...)
        if depth > 4 then return end
        for i = 1, select("#", ...) do
            local child = select(i, ...)
            if IsLikelyItemButton(child) then
                AddButton(child)
            end
            ProcessContainerChildren(depth + 1, child:GetChildren())
        end
    end
    if containerFrame then
        ProcessContainerChildren(1, containerFrame:GetChildren())
    end

    return buttons
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
            -- Store reference
            table.insert(containerButtons, button)

            -- Create overlay
            Overlay:AddToFrame(button, function()
                UpdateContainerButton(button)
            end)

            -- Hook updates
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

local function OnBagUpdate()
    -- Frames can be rebuilt dynamically; re-scan hook targets then refresh.
    HookAllContainers()
    UpdateAllContainerOverlays()
end

local function OnBankOpened()
    HookBankFrame()
    UpdateAllContainerOverlays()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function Initialize()
    -- Register callbacks
    Events:RegisterCallback("bags", OnBagUpdate)

    -- Hook Blizzard functions
    if ToggleBag then
        hooksecurefunc("ToggleBag", function()
            C_Timer.After(0.1, HookAllContainers)
        end)
    end

    if OpenAllBags then
        hooksecurefunc("OpenAllBags", function()
            C_Timer.After(0.1, HookAllContainers)
        end)
    end

    if ToggleAllBags then
        hooksecurefunc("ToggleAllBags", function()
            C_Timer.After(0.1, HookAllContainers)
        end)
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
