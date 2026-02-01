--[[
    Homestead - Merchant Overlays
    Overlays for vendor/merchant frames
]]

local addonName, HA = ...

-- Wait for Overlay module
local Overlay = HA.Overlay
local Events = HA.Events

-- Local state
local isHooked = false
local merchantButtons = {}

-------------------------------------------------------------------------------
-- Merchant Item Update Function
-------------------------------------------------------------------------------

local function UpdateMerchantButton(button, index)
    if not button then return end

    local overlay = button.HousingAddonOverlay
    if not overlay then
        overlay = Overlay:AddToFrame(button)
    end

    if not overlay then return end

    -- Get item link from merchant
    local itemLink = GetMerchantItemLink(index)
    Overlay:SetIcon(overlay, itemLink)
end

-------------------------------------------------------------------------------
-- Merchant Frame Hooking
-------------------------------------------------------------------------------

local function HookMerchantFrame()
    if isHooked then return end

    -- Get merchant items per page (typically 10)
    local itemsPerPage = MERCHANT_ITEMS_PER_PAGE or 10

    for i = 1, itemsPerPage do
        local buttonName = "MerchantItem" .. i .. "ItemButton"
        local button = _G[buttonName]

        if button and not button.HousingAddonHooked then
            -- Store reference
            merchantButtons[i] = button

            -- Create overlay with update function
            Overlay:AddToFrame(button, function(overlay)
                local index = button:GetID()
                if MerchantFrame.page then
                    index = index + ((MerchantFrame.page - 1) * itemsPerPage)
                end
                UpdateMerchantButton(button, index)
            end)

            button.HousingAddonHooked = true
        end
    end

    -- Hook page navigation buttons
    local nextButton = MerchantNextPageButton
    if nextButton and not nextButton.HousingAddonPageHooked then
        nextButton:HookScript("OnClick", function()
            C_Timer.After(0.1, UpdateAllMerchantOverlays)
        end)
        nextButton.HousingAddonPageHooked = true
    end

    local prevButton = MerchantPrevPageButton
    if prevButton and not prevButton.HousingAddonPageHooked then
        prevButton:HookScript("OnClick", function()
            C_Timer.After(0.1, UpdateAllMerchantOverlays)
        end)
        prevButton.HousingAddonPageHooked = true
    end

    -- Hook tab switching
    local tab1 = MerchantFrameTab1
    if tab1 and not tab1.HousingAddonTabHooked then
        tab1:HookScript("OnClick", function()
            C_Timer.After(0.1, UpdateAllMerchantOverlays)
        end)
        tab1.HousingAddonTabHooked = true
    end

    local tab2 = MerchantFrameTab2
    if tab2 and not tab2.HousingAddonTabHooked then
        tab2:HookScript("OnClick", function()
            C_Timer.After(0.1, UpdateAllMerchantOverlays)
        end)
        tab2.HousingAddonTabHooked = true
    end

    -- Hook mouse wheel scrolling
    local merchantFrame = MerchantFrame
    if merchantFrame and not merchantFrame.HousingAddonScrollHooked then
        merchantFrame:HookScript("OnMouseWheel", function()
            C_Timer.After(0.1, UpdateAllMerchantOverlays)
        end)
        merchantFrame.HousingAddonScrollHooked = true
    end

    isHooked = true
    HA.Addon:Debug("Merchant frame hooked")
end

-------------------------------------------------------------------------------
-- Update Functions
-------------------------------------------------------------------------------

function UpdateAllMerchantOverlays()
    local itemsPerPage = MERCHANT_ITEMS_PER_PAGE or 10

    for i = 1, itemsPerPage do
        local button = merchantButtons[i]
        if button then
            local index = i
            if MerchantFrame and MerchantFrame.page then
                index = i + ((MerchantFrame.page - 1) * itemsPerPage)
            end
            UpdateMerchantButton(button, index)
        end
    end
end

-------------------------------------------------------------------------------
-- Event Handlers
-------------------------------------------------------------------------------

local function OnMerchantShow()
    HookMerchantFrame()
    C_Timer.After(0.1, UpdateAllMerchantOverlays)
end

local function OnMerchantClosed()
    -- Clean up overlays
    for _, button in pairs(merchantButtons) do
        if button and button.HousingAddonOverlay then
            Overlay:ClearIcon(button.HousingAddonOverlay)
        end
    end
end

local function OnMerchantUpdate()
    UpdateAllMerchantOverlays()
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

local function Initialize()
    -- Register callbacks
    Events:RegisterCallback("merchant", UpdateAllMerchantOverlays)

    -- Register for merchant events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("MERCHANT_UPDATE")
    frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            OnMerchantShow()
        elseif event == "MERCHANT_CLOSED" then
            OnMerchantClosed()
        elseif event == "MERCHANT_UPDATE" then
            OnMerchantUpdate()
        end
    end)

    HA.Addon:Debug("Merchant overlay module initialized")
end

-- Initialize when addon loads
if HA.Addon then
    C_Timer.After(0, Initialize)
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", Initialize)
end
