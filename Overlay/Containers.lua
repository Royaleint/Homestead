--[[
    HousingAddon - Container Overlays
    Overlays for bags and bank frames
]]

local addonName, HA = ...

-- Wait for Overlay module
local Overlay = HA.Overlay
local Events = HA.Events

-- Local state
local isHooked = false
local containerButtons = {}

-------------------------------------------------------------------------------
-- Bag Item Update Function
-------------------------------------------------------------------------------

local function UpdateContainerButton(button)
    if not button then return end

    local overlay = button.HousingAddonOverlay
    if not overlay then
        overlay = Overlay:AddToFrame(button)
    end

    if not overlay then return end

    -- Get item link from the button
    local itemLink = nil

    -- Try to get bag and slot from button
    local bag = button:GetParent() and button:GetParent():GetID()
    local slot = button:GetID()

    if bag and slot then
        itemLink = C_Container.GetContainerItemLink(bag, slot)
    end

    Overlay:SetIcon(overlay, itemLink)
end

-------------------------------------------------------------------------------
-- Container Frame Hooking
-------------------------------------------------------------------------------

local function HookContainerFrame(containerFrame)
    if not containerFrame then return end

    -- Hook the container's items
    local items = containerFrame.Items
    if items then
        for _, button in ipairs(items) do
            if not button.HousingAddonHooked then
                -- Store reference
                table.insert(containerButtons, button)

                -- Create overlay
                Overlay:AddToFrame(button, UpdateContainerButton)

                -- Hook updates
                button:HookScript("OnShow", function(self)
                    UpdateContainerButton(self)
                end)

                hooksecurefunc(button, "SetItemButtonTexture", function(self)
                    -- Delay slightly to ensure item data is available
                    C_Timer.After(0, function()
                        UpdateContainerButton(self)
                    end)
                end)

                button.HousingAddonHooked = true
            end
        end
    end
end

local function HookAllContainers()
    if isHooked then return end

    -- Hook combined bags frame
    local combinedBags = ContainerFrameCombinedBags
    if combinedBags then
        HookContainerFrame(combinedBags)
    end

    -- Hook individual bag frames
    local frameContainer = ContainerFrameContainer
    if frameContainer and frameContainer.ContainerFrames then
        for _, bagFrame in ipairs(frameContainer.ContainerFrames) do
            HookContainerFrame(bagFrame)
        end
    end

    isHooked = true
    HA.Addon:Debug("Container frames hooked")
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
                local itemLink = GetContainerItemLink(BANK_CONTAINER, i)
                Overlay:SetIcon(overlay, itemLink)
            end)
            button.HousingAddonHooked = true
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
    -- Throttled through Events system
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
