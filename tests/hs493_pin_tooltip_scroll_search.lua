-- luacheck: globals assert loadfile print io error pcall setmetatable tostring type string table math ipairs pairs select unpack
-- luacheck: globals CreateFrame UIParent C_Timer C_Item C_CurrencyInfo Item BaseScrollBoxEvents ScrollBoxConstants

local root, modulePath = ...
root = (root or "."):gsub("\\\\", "/"):gsub("/+$", "")
modulePath = modulePath or (root .. "/UI/VendorPinTooltips.lua")

-------------------------------------------------------------------------------
-- HS-493: vendor pin tooltip with a scroll bar and search box for long wares
-- lists. Loads the whole UI/VendorPinTooltips.lua against stub frames and
-- drives it through ShowVendorTooltip, wheel, bar, search, leave and rebuild
-- paths. Run with a second argument (a path to another copy of the module) to
-- run only the plain-path call-log section against that copy.
-------------------------------------------------------------------------------

local PLAIN_NAME = "HomesteadVendorMapPinsTooltip"
local INTERACTIVE_NAME = "HomesteadVendorMapPinsWaresTooltip"

local world

local function Fail(message)
    error(message, 2)
end

local function Check(condition, message)
    if not condition then Fail(message) end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        Fail(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

-------------------------------------------------------------------------------
-- Stub frames
-------------------------------------------------------------------------------

local function Serialize(value)
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "table" then return value.stubName or "table" end
    return tostring(value)
end

local function FormatCall(method, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = Serialize((select(index, ...)))
    end
    return method .. "(" .. table.concat(parts, ",") .. ")"
end

local function Fire(frame, scriptName, ...)
    local script = frame.scripts[scriptName]
    if script then script(frame, ...) end
    for _, hook in ipairs(frame.hooks[scriptName] or {}) do
        hook(frame, ...)
    end
end

local NewFrame

local FRAME_METHODS = {}

-- Methods the plain tooltip frame must never receive (the base file's behavior).
local PLAIN_FORBIDDEN = {
    EnableMouse = true, EnableMouseWheel = true, EnableKeyboard = true,
    SetPadding = true, SetMinimumWidth = true, SetScript = true, HookScript = true,
}

function FRAME_METHODS:SetFrameStrata() end
function FRAME_METHODS:SetClampedToScreen() end
function FRAME_METHODS:EnableMouse() end
function FRAME_METHODS:EnableMouseWheel() end
function FRAME_METHODS:SetOwner(owner) self.owner = owner end
function FRAME_METHODS:GetOwner() return self.owner end
function FRAME_METHODS:ClearLines() self.lines = {} end
function FRAME_METHODS:AddLine(text) self.lines[#self.lines + 1] = { left = text } end
function FRAME_METHODS:AddDoubleLine(left, right) self.lines[#self.lines + 1] = { left = left, right = right } end
function FRAME_METHODS:ClearAllPoints() self.points = {} end
function FRAME_METHODS:SetPoint(...) self.points[#self.points + 1] = { ... } end
function FRAME_METHODS:SetMinimumWidth(width) self.minWidth = width end
function FRAME_METHODS:SetPadding(right, bottom) self.padding = { right, bottom } end
function FRAME_METHODS:SetHeight() end
function FRAME_METHODS:GetWidth() return self.width end
function FRAME_METHODS:GetHeight() return self.height end
function FRAME_METHODS:GetRight() return self.right end
function FRAME_METHODS:GetTop() return self.top end
function FRAME_METHODS:GetEffectiveScale() return self.scale end
function FRAME_METHODS:IsMouseOver() return self.mouseOver end
function FRAME_METHODS:RegisterEvent(event) self.events[event] = true end
function FRAME_METHODS:UnregisterEvent(event) self.events[event] = nil end
function FRAME_METHODS:SetScript(name, fn) self.scripts[name] = fn end
function FRAME_METHODS:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
end
function FRAME_METHODS:IsShown() return self.shown end
function FRAME_METHODS:Show()
    if self.shown then return end
    self.shown = true
    Fire(self, "OnShow")
end
function FRAME_METHODS:Hide()
    if not self.shown then return end
    self.shown = false
    Fire(self, "OnHide")
end
function FRAME_METHODS:SetAutoFocus() end
function FRAME_METHODS:SetMaxLetters() end
function FRAME_METHODS:GetText() return self.text end
function FRAME_METHODS:SetText(text)
    self.text = text
    Fire(self, "OnTextChanged", false)
end
function FRAME_METHODS:HasFocus() return self.focused end
function FRAME_METHODS:SetFocus()
    if self.focused then return end
    self.focused = true
    Fire(self, "OnEditFocusGained")
end
function FRAME_METHODS:ClearFocus()
    if not self.focused then return end
    self.focused = false
    Fire(self, "OnEditFocusLost")
end
function FRAME_METHODS:Init() end
function FRAME_METHODS:RegisterCallback(event, fn, owner)
    self.callbacks[event] = { fn = fn, owner = owner }
end
function FRAME_METHODS:SetVisibleExtentPercentage() end
function FRAME_METHODS:SetPanExtentPercentage() end
function FRAME_METHODS:SetScrollPercentage(percentage)
    self.scrollPercentage = percentage
    local callback = self.callbacks[BaseScrollBoxEvents.OnScroll]
    if callback then callback.fn(callback.owner, percentage) end
end
function FRAME_METHODS:UnregisterUpdate() self.unregisterUpdates = self.unregisterUpdates + 1 end
function FRAME_METHODS:GetThumb() return self.thumb end
function FRAME_METHODS:GetTrack() return self.track end
function FRAME_METHODS:GetBackStepper() return self.back end
function FRAME_METHODS:GetForwardStepper() return self.forward end

NewFrame = function(frameType, name, parent, template)
    local frame = {
        stubName = name or (frameType .. "#" .. (#world.frames + 1)),
        frameType = frameType, name = name, parent = parent, template = template,
        shown = false, scripts = {}, hooks = {}, events = {}, callbacks = {},
        lines = {}, points = {}, text = "", focused = false, mouseOver = false,
        width = 320, height = 300, scale = 1, right = 100, top = 600,
        unregisterUpdates = 0, calls = {},
    }
    local isPlain = name == PLAIN_NAME
    local isEventFrame = frameType == "Frame" and not name and #world.frames == 0
    return setmetatable(frame, {
        __index = function(_, method)
            local fn = FRAME_METHODS[method]
            if not fn then
                -- Data fields read as nil; only an unknown method (capitalized) is an error.
                if type(method) == "string" and method:match("^%u") then
                    error("unexpected frame method: " .. method, 2)
                end
                return nil
            end
            return function(self, ...)
                if isPlain and PLAIN_FORBIDDEN[method] then
                    error("plain tooltip received " .. method, 2)
                end
                if isPlain or isEventFrame then
                    local line = (isPlain and "plain:" or "events:") .. FormatCall(method, ...)
                    world.log[#world.log + 1] = line
                end
                return fn(self, ...)
            end
        end,
    })
end

local function CreateStubFrame(frameType, name, parent, template)
    if name == INTERACTIVE_NAME then world.interactiveCreated = true end
    if name == PLAIN_NAME then world.plainCreated = true end
    local frame = NewFrame(frameType, name, parent, template)
    world.frames[#world.frames + 1] = frame
    if template == "MinimalScrollBar" then
        frame.thumb = NewFrame("Button", nil, frame)
        frame.track = NewFrame("Frame", nil, frame)
        frame.back = NewFrame("Button", nil, frame)
        frame.forward = NewFrame("Button", nil, frame)
        frame.shown = true
    elseif template == "SearchBoxTemplate" then
        frame.clearButton = NewFrame("Button", nil, frame)
    end
    return frame
end

local function NewPin(name, props)
    local pin = { stubName = name, right = 100, top = 600, scale = 1, mouseOver = false }
    for key, value in pairs(props or {}) do pin[key] = value end
    function pin:GetRight() return self.right end
    function pin:GetTop() return self.top end
    function pin:GetEffectiveScale() return self.scale end
    function pin:IsMouseOver() return self.mouseOver end
    return pin
end

-------------------------------------------------------------------------------
-- World: stubs for the game API and addon namespace, rebuilt per module load
-------------------------------------------------------------------------------

local function FindFrame(name)
    for _, frame in ipairs(world.frames) do
        if frame.name == name then return frame end
    end
end

local function FireTimers()
    local queue = world.timers
    world.timers = {}
    for _, timer in ipairs(queue) do
        if not timer.cancelled then
            timer.fn()
        end
    end
end

local function PendingTimers()
    local count = 0
    for _, timer in ipairs(world.timers) do
        if not timer.cancelled then count = count + 1 end
    end
    return count
end

local function NewWorld()
    world = {
        frames = {}, timers = {}, log = {},
        names = {}, currencies = {}, availability = {}, loadCallbacks = {},
        calls = {
            GetItemInfo = 0, GetItemNameByID = 0, GetCurrencyInfo = 0, CreateFromItemID = 0,
            GetItemPresentation = 0, GetVendorItemCost = 0, GetVendorStats = 0,
            GetScannedVendorRecord = 0, GetItemsForVendor = 0, GetItemCost = 0, NormalizeScannedCost = 0,
        },
    }

    CreateFrame = CreateStubFrame
    UIParent = NewPin("UIParent", { width = 1920, scale = 1 })
    function UIParent:GetWidth() return self.width end
    BaseScrollBoxEvents = { OnScroll = "OnScroll" }
    ScrollBoxConstants = { NoScrollInterpolation = true }
    C_Timer = {
        After = function(_, fn)
            world.timers[#world.timers + 1] = { fn = fn }
        end,
        NewTimer = function(_, fn)
            local timer = { fn = fn }
            function timer.Cancel() timer.cancelled = true end
            world.timers[#world.timers + 1] = timer
            return timer
        end,
    }
    C_Item = {
        GetItemInfo = function(itemID)
            world.calls.GetItemInfo = world.calls.GetItemInfo + 1
            return world.names[itemID]
        end,
        GetItemNameByID = function(itemID)
            world.calls.GetItemNameByID = world.calls.GetItemNameByID + 1
            return world.names[itemID]
        end,
    }
    C_CurrencyInfo = {
        GetCurrencyInfo = function(currencyID)
            world.calls.GetCurrencyInfo = world.calls.GetCurrencyInfo + 1
            return world.currencies[currencyID]
        end,
    }
    Item = {
        CreateFromItemID = function(_, itemID)
            world.calls.CreateFromItemID = world.calls.CreateFromItemID + 1
            return {
                ContinueOnItemLoad = function(_, fn)
                    world.loadCallbacks[itemID] = fn
                end,
            }
        end,
    }

    local HA = {
        L = setmetatable({}, { __index = function(_, key) return key end }),
        Addon = { db = { profile = { vendorTracer = { showVendorPinItemDetails = true } } } },
        BadgeCalculation = {
            AddSummaryLine = function(tooltip, collected, total, locked, unverified)
                tooltip:AddLine(string.format("summary %s/%s/%s/%s", collected, total, locked, unverified))
            end,
        },
        VendorMapPins = {
            IsOppositeFaction = function(_, vendor) return vendor.opposite == true end,
            GetActiveSourceFilter = function() return "all" end,
            CanAccessVendor = function() return false end,
            GetVendorStats = function(_, vendor)
                world.calls.GetVendorStats = world.calls.GetVendorStats + 1
                return vendor.stats or { total = #(vendor.static or {}), collected = 0, locked = 0, unverified = 0 }
            end,
        },
        VendorData = {
            GetScannedVendorRecord = function(_, vendor)
                world.calls.GetScannedVendorRecord = world.calls.GetScannedVendorRecord + 1
                return vendor.scanned
            end,
            NormalizeScannedCost = function(_, item)
                world.calls.NormalizeScannedCost = world.calls.NormalizeScannedCost + 1
                return item.cost
            end,
            GetItemsForVendor = function(_, vendor)
                world.calls.GetItemsForVendor = world.calls.GetItemsForVendor + 1
                return vendor.static or {}
            end,
            GetItemID = function(_, item) return item.itemID end,
            GetItemCost = function(_, item)
                world.calls.GetItemCost = world.calls.GetItemCost + 1
                return item.cost
            end,
            FormatCost = function(_, cost)
                if not cost then return "?" end
                return cost.text or "cost"
            end,
        },
        SourceManager = {
            GetItemPresentation = function(_, itemID)
                world.calls.GetItemPresentation = world.calls.GetItemPresentation + 1
                return { availabilityState = world.availability[itemID] }
            end,
            GetVendorItemCost = function(_, _, _, scannedCost, _, cost)
                world.calls.GetVendorItemCost = world.calls.GetVendorItemCost + 1
                return cost or scannedCost
            end,
        },
    }
    world.HA = HA
    return HA
end

local function LoadModule(path)
    local HA = NewWorld()
    local chunk = assert(loadfile(path or modulePath))
    chunk("Homestead", HA)
    local module = HA.VendorPinTooltips
    Check(module, "module did not register HA.VendorPinTooltips")
    world.eventFrame = world.frames[1]
    return module, HA
end

-------------------------------------------------------------------------------
-- Fixtures
-------------------------------------------------------------------------------

local function MakeVendor(count, props)
    local vendor = { name = "Test Vendor", zone = "Test Zone", npcID = 4242, static = {} }
    for index = 1, count do
        local itemID = 10000 + index
        world.names[itemID] = "Ware " .. index
        vendor.static[index] = { itemID = itemID, cost = { text = "cost " .. index } }
    end
    for key, value in pairs(props or {}) do vendor[key] = value end
    return vendor
end

local function RowNames(frame)
    local rows = {}
    for _, line in ipairs(frame.lines) do
        local name = line.left and line.left:match("^  (Ware %d+)")
        if name then rows[#rows + 1] = name end
    end
    return rows
end

local function Describe(rows)
    return #rows == 0 and "(none)" or (rows[1] .. ".." .. rows[#rows] .. " x" .. #rows)
end

local function ExpectRows(frame, first, last, message)
    local rows = RowNames(frame)
    local expected = {}
    for index = first, last do expected[#expected + 1] = "Ware " .. index end
    Equal(Describe(rows), Describe(expected), message)
end

-------------------------------------------------------------------------------
-- Case 0: smoke. Plain path under the threshold, interactive path above it.
-------------------------------------------------------------------------------

do
    local module = LoadModule()
    local pin = NewPin("pinA")

    module:ShowVendorTooltip(pin, MakeVendor(15))
    local plain = FindFrame(PLAIN_NAME)
    Check(plain and plain.shown, "15 wares must show the plain tooltip")
    local owned = false
    for _, line in ipairs(world.log) do
        if line == 'plain:SetOwner(pinA,"ANCHOR_RIGHT")' then owned = true end
    end
    Check(owned, "plain path must own the tooltip to the pin")
    Check(not world.interactiveCreated, "15 wares must not create the interactive frame")
    module:OnPinLeave()

    module:ShowVendorTooltip(pin, MakeVendor(16))
    local interactive = FindFrame(INTERACTIVE_NAME)
    Check(interactive and interactive.shown, "16 wares must show the interactive tooltip")
    Check(not plain.shown, "the plain tooltip must be hidden under the interactive one")
    ExpectRows(interactive, 1, 15, "first window")

    interactive.scripts.OnMouseWheel(interactive, -1)
    ExpectRows(interactive, 2, 16, "one wheel notch down")

    Equal(PendingTimers(), 0, "a real first width needs no retry timer")

    interactive.scripts.OnLeave(interactive)
    Check(interactive.shown, "a leave check must wait for the next frame")
    FireTimers()
    Check(not interactive.shown, "leaving with the cursor on neither frame must close the tooltip")

    module:ShowVendorTooltip(pin, MakeVendor(16))
    Check(interactive.shown, "a new hover must reopen the interactive tooltip")
    module:HidePinTooltip()
    Check(not interactive.shown, "HidePinTooltip must hide the interactive tooltip")
    for _, frame in ipairs(world.frames) do
        Check(not frame.focused, "no frame may hold focus after a close")
    end
end

print("hs493_pin_tooltip_scroll_search: ok")
