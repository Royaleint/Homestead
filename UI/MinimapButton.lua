local _, HA = ...

-- HA.MinimapButton — self-contained custom minimap button (replaces LibDBIcon rendering).
-- Position math is matched to LibDBIcon for zero-jump migration: same `minimapPos` key,
-- default 225 deg, edge radius 5px, atan2 drag. Behavior (clicks/tooltip) is delegated to
-- the LibDataBroker data object so it is defined in exactly one place (Core/core.lua).
local MinimapButton = {}
HA.MinimapButton = MinimapButton

local DEFAULT_ANGLE = 225   -- LibDBIcon default (LibDBIcon-1.0.lua:157)
local EDGE_RADIUS   = 5     -- LibDBIcon lib.radius default (LibDBIcon-1.0.lua:19)
local BUTTON_SIZE   = 50    -- frame is square; pin art is 43x63 of 64 (67% w x 98% h), so
                            -- visible pin ~= 34x49 px. Settled at Gate 2 against neighbor buttons.

-- Which quadrants are rounded for each minimap shape. Quadrant index:
--   q = 1 (+x,-y)  +1 if x<0 (-> 2)  +2 if y>0 (-> 3/4)
local MINIMAP_SHAPES = {
    ["ROUND"]                 = { true,  true,  true,  true },
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { false, false, false, true },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
    ["SIDE-LEFT"]             = { false, true,  false, true },
    ["SIDE-RIGHT"]            = { true,  false, true,  false },
    ["SIDE-TOP"]              = { false, false, true,  true },
    ["SIDE-BOTTOM"]           = { true,  true,  false, false },
    ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

local button      -- the Button frame (created in Initialize)
local dataObject  -- LibDataBroker object (behavior source)
local savedPos    -- db.profile.minimap table

local function ApplyPosition()
    if not button then return end
    local angle = math.rad(savedPos.minimapPos or DEFAULT_ANGLE)
    local x, y, q = math.cos(angle), math.sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local GetMinimapShape = _G.GetMinimapShape
    local Minimap = _G.Minimap
    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local quad = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES["ROUND"]
    local w = (Minimap:GetWidth() / 2) + EDGE_RADIUS
    local h = (Minimap:GetHeight() / 2) + EDGE_RADIUS
    if quad[q] then
        x, y = x * w, y * h
    else
        local diagW = math.sqrt(2 * w * w) - 10
        local diagH = math.sqrt(2 * h * h) - 10
        x = math.max(-w, math.min(x * diagW, w))
        y = math.max(-h, math.min(y * diagH, h))
    end
    -- No ClearAllPoints: SetPoint("CENTER", ...) overwrites the single existing CENTER
    -- anchor. This keeps the button collector-safe -- MinimapButtonBag-style addons grab
    -- the button and neutralize its SetPoint; without a ClearAllPoints our update becomes a
    -- harmless no-op instead of unanchoring the button (matches LibDBIcon/ATT behavior).
    button:SetPoint("CENTER", Minimap, "CENTER", math.floor(x + 0.5), math.floor(y + 0.5))
end

local function OnDragUpdate()
    local Minimap = _G.Minimap
    local GetCursorPosition = _G.GetCursorPosition
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    savedPos.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
    ApplyPosition()
end

local function OnDragStart(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", OnDragUpdate)
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end

local function OnClick(self, mouseButton)
    if dataObject and dataObject.OnClick then
        dataObject.OnClick(self, mouseButton)
    end
end

local function OnEnter(self)
    if dataObject and dataObject.OnTooltipShow then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        dataObject.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end
end

local function OnLeave()
    GameTooltip:Hide()
end

-- obj: the LibDataBroker data object. minimapDB: db.profile.minimap (has .hide, .minimapPos).
function MinimapButton:Initialize(obj, minimapDB)
    if button then return end  -- idempotent
    dataObject = obj
    savedPos = minimapDB

    -- Named (not unnamed) so minimap-button collectors (MinimapButtonBag Reborn, etc.) can
    -- find it via Minimap:GetChildren() + GetName(). The global is allowlisted in .luacheckrc.
    button = CreateFrame("Button", "HomesteadMinimapButton", _G.Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(obj.icon)
    button.icon = icon

    -- Shape-matched hover glow (no circular ring): brighten the pin itself.
    button:SetHighlightTexture(obj.icon, "ADD")

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)

    -- Reposition after login and on minimap shape/size changes (engine events).
    button:RegisterEvent("PLAYER_ENTERING_WORLD")
    button:RegisterEvent("LOADING_SCREEN_DISABLED")
    button:SetScript("OnEvent", ApplyPosition)

    ApplyPosition()
    if savedPos and savedPos.hide then
        button:Hide()
    else
        button:Show()
    end
end

function MinimapButton:Show()
    if button then button:Show() end
end

function MinimapButton:Hide()
    if button then button:Hide() end
end
