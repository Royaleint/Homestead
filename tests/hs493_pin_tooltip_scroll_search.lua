-- luacheck: globals assert loadfile print io error pcall setmetatable tostring type string table math ipairs pairs select unpack
-- luacheck: globals CreateFrame UIParent C_Timer C_Item C_CurrencyInfo Item BaseScrollBoxEvents ScrollBoxConstants

local root, modulePath, mode = ...
local customModule = modulePath ~= nil and modulePath ~= ""
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
function FRAME_METHODS:AddLine(text, _, _, _, wrap) self.lines[#self.lines + 1] = { left = text, wrap = wrap } end
function FRAME_METHODS:AddDoubleLine(left, right) self.lines[#self.lines + 1] = { left = left, right = right } end
function FRAME_METHODS:ClearAllPoints() self.points = {} end
function FRAME_METHODS:SetPoint(...) self.points[#self.points + 1] = { ... } end
function FRAME_METHODS:SetMinimumWidth(width) self.minWidth = width end
function FRAME_METHODS:SetPadding(right, bottom) self.padding = { right, bottom } end
function FRAME_METHODS:SetHeight() end
function FRAME_METHODS:GetWidth()
    if self.widthModel then return self.widthModel(self) end
    return self.width
end
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
    -- A real bar can report a position off by rounding; scrollJitter simulates that.
    if callback then callback.fn(callback.owner, percentage + (self.scrollJitter or 0)) end
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
        unregisterUpdates = 0, counts = {},
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
                self.counts[method] = (self.counts[method] or 0) + 1
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
        local name = line.left and line.left:match("^  (.-)%s*$")
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

local function ExpectNames(frame, names, message)
    Equal(table.concat(RowNames(frame), "|"), table.concat(names, "|"), message)
end

-- Everything from the summary line down: the footer, which a search must not change.
local function Footer(frame)
    local out = {}
    local started = false
    for _, line in ipairs(frame.lines) do
        if line.left and line.left:match("^summary") then started = true end
        if started then out[#out + 1] = line.left end
    end
    return table.concat(out, "|")
end

local function CountLines(frame, text)
    local count = 0
    for _, line in ipairs(frame.lines) do
        if line.left == text then count = count + 1 end
    end
    return count
end

local function FindTemplate(template)
    for _, frame in ipairs(world.frames) do
        if frame.template == template then return frame end
    end
end

local function Wheel(frame, delta)
    frame.scripts.OnMouseWheel(frame, delta)
end

local function Search(box, text)
    box:SetText(text)
    FireTimers()
end

local function Renders(frame)
    return frame.counts.ClearLines or 0
end

-- Opens `vendor` on pinA of a fresh module.
local function OpenVendor(module, HA, vendor)
    local pin = NewPin("pinA")
    module:ShowVendorTooltip(pin, vendor)
    local frame = FindFrame(INTERACTIVE_NAME)
    Check(frame and frame.shown, "the vendor must open the interactive tooltip")
    return {
        module = module, HA = HA, pin = pin, vendor = vendor, frame = frame,
        box = FindTemplate("SearchBoxTemplate"), bar = FindTemplate("MinimalScrollBar"),
    }
end

local function OpenLong(count)
    local module, HA = LoadModule()
    return OpenVendor(module, HA, MakeVendor(count))
end

-------------------------------------------------------------------------------
-- Plain path: same calls as the base file.
-------------------------------------------------------------------------------

local GOLDEN = {}
-- GOLDEN-BEGIN
-- Recorded by running this section against the base copy of the module.
GOLDEN["empty"] = [==[
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
plain:SetFrameStrata("TOOLTIP")
plain:SetClampedToScreen(true)
plain:SetOwner(pinI1,"ANCHOR_RIGHT")
plain:ClearLines()
plain:AddLine("Test Vendor",1,1,1)
plain:AddLine("Test Zone",0.7,0.7,0.7)
plain:AddLine(" ")
plain:AddLine("Item data unknown - visit vendor to scan",1,0.82,0)
plain:AddLine(" ")
plain:AddLine("Left-click to set waypoint",0.5,0.5,0.5)
plain:Show()
events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
plain:Hide()
]==]
GOLDEN["one ware"] = [==[
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
plain:SetFrameStrata("TOOLTIP")
plain:SetClampedToScreen(true)
plain:SetOwner(pinI1,"ANCHOR_RIGHT")
plain:ClearLines()
plain:AddLine("Test Vendor",1,1,1)
plain:AddLine("Test Zone",0.7,0.7,0.7)
plain:AddLine(" ")
plain:AddLine("Items Sold:",1,1,0)
plain:AddDoubleLine("  Ware 1","cost 1",1,1,1,1,0.82,0)
plain:AddLine(" ")
plain:AddLine("summary 1/1/0/0")
plain:AddLine(" ")
plain:AddLine("Left-click to set waypoint",0.5,0.5,0.5)
plain:Show()
events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
plain:Hide()
]==]
GOLDEN["fifteen wares details on"] = [==[
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
plain:SetFrameStrata("TOOLTIP")
plain:SetClampedToScreen(true)
plain:SetOwner(pinI1,"ANCHOR_RIGHT")
plain:ClearLines()
plain:AddLine("Test Vendor",1,1,1)
plain:AddLine("Test Subzone (Test Zone)",0.7,0.7,0.7)
plain:AddLine("Alliance",0,0.44,0.87)
plain:AddLine(" ")
plain:AddLine("Items Sold:",1,1,0)
plain:AddDoubleLine("  Ware 1","cost 1",0,1,0,1,0.82,0)
plain:AddDoubleLine("  Ware 2","cost 2",1,0.25,0.25,1,0.82,0)
plain:AddDoubleLine("  Ware 3","cost 3",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 4","cost 4",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 5","cost 5",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 6","cost 6",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 7","cost 7",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 8","cost 8",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 9","cost 9",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 10","cost 10",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 11","cost 11",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 12","cost 12",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 13","cost 13",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 14","cost 14",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Scanned Ware","scanned",1,1,1,1,0.82,0)
plain:AddLine(" ")
plain:AddLine("summary 2/15/1/0")
plain:AddLine("Vendor-only: 3",0.85,0.85,0.85)
plain:AddLine(" ")
plain:AddLine("Left-click to set waypoint",0.5,0.5,0.5)
plain:Show()
events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
plain:Hide()
]==]
GOLDEN["fifteen wares details off"] = [==[
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
plain:SetFrameStrata("TOOLTIP")
plain:SetClampedToScreen(true)
plain:SetOwner(pinI1,"ANCHOR_RIGHT")
plain:ClearLines()
plain:AddLine("Test Vendor",1,1,1)
plain:AddLine("Test Zone",0.7,0.7,0.7)
plain:AddLine("Horde",0.77,0.12,0.23)
plain:AddLine(" ")
plain:AddLine("Items Sold:",1,1,0)
plain:AddLine("  Ware 1",1,1,1)
plain:AddLine("  Ware 2",1,1,1)
plain:AddLine("  Ware 3",0,1,0)
plain:AddLine("  Ware 4",1,1,1)
plain:AddLine("  Ware 5",1,1,1)
plain:AddLine("  Ware 6",1,1,1)
plain:AddLine("  Ware 7",1,1,1)
plain:AddLine("  Ware 8",1,1,1)
plain:AddLine("  Ware 9",1,1,1)
plain:AddLine("  Ware 10",1,1,1)
plain:AddLine("  Ware 11",1,1,1)
plain:AddLine("  Ware 12",1,1,1)
plain:AddLine("  Ware 13",1,1,1)
plain:AddLine("  Ware 14",1,1,1)
plain:AddLine("  Ware 15",1,1,1)
plain:AddLine(" ")
plain:AddLine("summary 2/15/1/0")
plain:AddLine(" ")
plain:AddLine("Left-click to set waypoint",0.5,0.5,0.5)
plain:Show()
events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
plain:Hide()
]==]
GOLDEN["fifteen wares opposite faction"] = [==[
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
plain:SetFrameStrata("TOOLTIP")
plain:SetClampedToScreen(true)
plain:SetOwner(pinI1,"ANCHOR_RIGHT")
plain:ClearLines()
plain:AddLine("Test Vendor",1,1,1)
plain:AddLine("Test Zone",0.7,0.7,0.7)
plain:AddLine("Horde",0.77,0.12,0.23)
plain:AddLine(" ")
plain:AddLine("Cannot access - opposite faction vendor",0.8,0.3,0.3)
plain:AddLine(" ")
plain:AddLine("Found behind the inn.",1,0.82,0,true)
plain:AddLine(" ")
plain:AddLine("Items Sold:",1,1,0)
plain:AddDoubleLine("  Ware 1","cost 1",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 2","cost 2",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 3","cost 3",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 4","cost 4",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 5","cost 5",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 6","cost 6",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 7","cost 7",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 8","cost 8",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 9","cost 9",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 10","cost 10",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 11","cost 11",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 12","cost 12",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 13","cost 13",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 14","cost 14",1,1,1,1,0.82,0)
plain:AddDoubleLine("  Ware 15","cost 15",1,1,1,1,0.82,0)
plain:AddLine(" ")
plain:AddLine("summary 0/15/4/1")
plain:AddLine("Vendor-only: 2",0.85,0.85,0.85)
plain:AddLine("Cannot buy on this character - opposite faction vendor",1,0.5,0.5)
plain:AddLine("Locked counts above only reflect requirement gates.",0.9,0.7,0.7)
plain:AddLine("Locked by: Reputation (3)",1,0.82,0)
plain:AddLine("Locked by: Quest (2)",1,0.82,0)
plain:AddLine("Locked by: Achievement (1)",1,0.82,0)
plain:AddLine("Locked by: +1 more blocker types",0.8,0.8,0.8)
plain:AddLine(" ")
plain:AddLine("Left-click to set waypoint (for alts)",0.5,0.5,0.5)
plain:Show()
events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
plain:Hide()
]==]
-- GOLDEN-END

local function Costs(vendor)
    for index, ware in ipairs(vendor.static) do
        ware.cost = { text = "cost " .. index, gold = index * 100 }
    end
end

local I1_FIXTURES = {
    { name = "empty", details = true, build = function() return MakeVendor(0, { stats = { total = 0 } }) end },
    { name = "one ware", details = true, build = function()
        return MakeVendor(1, { stats = { total = 1, collected = 1, locked = 0, unverified = 0 } })
    end },
    { name = "fifteen wares details on", details = true, build = function()
        local vendor = MakeVendor(14, {
            subzone = "Test Subzone", faction = "Alliance",
            scanned = { lastScanned = 5, items = { { itemID = 20001, name = "Scanned Ware", cost = { text = "scanned" } } } },
            stats = { total = 15, collected = 2, locked = 1, unverified = 0, vendorOnly = 3 },
        })
        Costs(vendor)
        world.availability[10001] = "owned"
        world.availability[10002] = "locked"
        return vendor
    end },
    { name = "fifteen wares details off", details = false, build = function()
        local vendor = MakeVendor(15, {
            faction = "Horde",
            stats = { total = 15, collected = 2, locked = 1, unverified = 0, vendorOnly = 3 },
        })
        Costs(vendor)
        world.availability[10003] = "owned"
        return vendor
    end },
    { name = "fifteen wares opposite faction", details = true, build = function()
        local vendor = MakeVendor(15, {
            opposite = true, notes = "Found behind the inn.", faction = "Horde",
            stats = {
                total = 15, collected = 0, locked = 4, unverified = 1, vendorOnly = 2,
                blockers = {
                    { label = "Reputation", count = 3 }, { label = "Quest", count = 2 },
                    { label = "Achievement", count = 1 }, { label = "Renown", count = 1 },
                },
            },
        })
        Costs(vendor)
        return vendor
    end },
}

local function RunPlainFixture(fixture)
    local module, HA = LoadModule()
    HA.Addon.db.profile.vendorTracer.showVendorPinItemDetails = fixture.details
    local vendor = fixture.build()
    world.log = {}
    module:ShowVendorTooltip(NewPin("pinI1"), vendor)
    module:OnPinLeave()
    Check(not world.interactiveCreated, fixture.name .. ": no interactive frame for a vendor at or under the threshold")
    return table.concat(world.log, "\n") .. "\n"
end

do
    if mode == "--print-golden" then
        for _, fixture in ipairs(I1_FIXTURES) do
            print(string.format("GOLDEN[%q] = [==[\n%s]==]", fixture.name, RunPlainFixture(fixture)))
        end
        return
    end
    for _, fixture in ipairs(I1_FIXTURES) do
        Check(GOLDEN[fixture.name], fixture.name .. ": no golden recorded")
        Equal(RunPlainFixture(fixture), GOLDEN[fixture.name], fixture.name .. ": plain call log")
    end
end

if customModule then
    print("hs493_pin_tooltip_scroll_search: plain path ok against " .. modulePath)
    return
end

-------------------------------------------------------------------------------
-- Smoke: plain path under the threshold, interactive path above it.
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

-------------------------------------------------------------------------------
-- Window and offset
-------------------------------------------------------------------------------

local function LargestStaticVendorCount()
    local offersHA = {}
    assert(loadfile(root .. "/Data/VendorOffers.lua"))("Homestead", offersHA)
    local offers = offersHA.VendorOffers
    local perNpc = {}
    for _, source in ipairs({ offers.GeneratedBase, offers.ManualOverrides }) do
        for npcID, items in pairs(source) do
            perNpc[npcID] = perNpc[npcID] or {}
            for itemID in pairs(items) do perNpc[npcID][itemID] = true end
        end
    end
    local largest = 0
    for _, items in pairs(perNpc) do
        local count = 0
        for _ in pairs(items) do count = count + 1 end
        if count > largest then largest = count end
    end
    return largest
end

do
    local largest = LargestStaticVendorCount()
    Check(largest > 15, "the offer data must hold a vendor with more than 15 wares")

    for _, count in ipairs({ 16, largest }) do
        local t = OpenLong(count)
        local label = count .. " wares: "
        ExpectRows(t.frame, 1, 15, label .. "first window")
        Check(t.bar.shown, label .. "the bar must show above 15 wares")

        Wheel(t.frame, -1)
        ExpectRows(t.frame, 2, 16, label .. "one notch down")

        for _ = 1, count + 5 do Wheel(t.frame, -1) end
        ExpectRows(t.frame, count - 14, count, label .. "past the end clamps with the final ware last")
        Equal(#RowNames(t.frame), 15, label .. "rows at the end")

        local before = Renders(t.frame)
        Wheel(t.frame, -1)
        Equal(Renders(t.frame), before, label .. "a notch at the end renders nothing")

        Wheel(t.frame, 1)
        ExpectRows(t.frame, count - 15, count - 1, label .. "one notch back up")

        for _ = 1, count + 5 do Wheel(t.frame, 1) end
        ExpectRows(t.frame, 1, 15, label .. "back at the top")
    end

    -- The bar's own scroll callback.
    local t = OpenLong(30)
    local callback = t.bar.callbacks.OnScroll
    Check(callback, "the scroll bar must have an OnScroll callback")
    local before = Renders(t.frame)
    Wheel(t.frame, -1)
    Equal(Renders(t.frame), before + 1, "one wheel notch renders once: the bar sync must not render again")
    before = Renders(t.frame)
    callback.fn(callback.owner, 1 / 15)
    Equal(Renders(t.frame), before, "a bar callback resolving to the current offset renders nothing")
    callback.fn(callback.owner, 1)
    ExpectRows(t.frame, 16, 30, "dragging the thumb to the end")
    callback.fn(callback.owner, 0)
    ExpectRows(t.frame, 1, 15, "dragging the thumb to the start")

    -- A position the bar reports off by rounding must not feed back into the offset.
    t = OpenLong(30)
    t.bar.scrollJitter = 0.05
    Wheel(t.frame, -1)
    ExpectRows(t.frame, 2, 16, "a bar sync that reports a rounded position")

    -- A search returns to the top.
    t = OpenLong(40)
    for _ = 1, 3 do Wheel(t.frame, -1) end
    ExpectRows(t.frame, 4, 18, "scrolled before searching")
    Search(t.box, "ware")
    ExpectRows(t.frame, 1, 15, "a search returns to the top")

    -- The bar shows if and only if more than 15 wares match.
    t = OpenLong(18)
    Check(t.bar.shown, "18 matches show the bar")
    for id = 10016, 10018 do world.names[id] = "Odd " .. id end
    t.module:ShowVendorTooltip(t.pin, t.vendor)
    Search(t.box, "ware")
    Equal(#RowNames(t.frame), 15, "15 matches fill the window")
    Check(not t.bar.shown, "15 matches hide the bar")
    world.names[10015] = "Odd 15"
    t.module:ShowVendorTooltip(t.pin, t.vendor)
    Search(t.box, "ware")
    Equal(#RowNames(t.frame), 14, "14 matches")
    Check(not t.bar.shown, "14 matches hide the bar")
    world.names[10015] = "Ware 15"
    world.names[10016] = "Ware 16"
    t.module:ShowVendorTooltip(t.pin, t.vendor)
    Search(t.box, "ware")
    Equal(#RowNames(t.frame), 15, "16 matches show 15 rows")
    Check(t.bar.shown, "16 matches show the bar")
end

-------------------------------------------------------------------------------
-- Search
-------------------------------------------------------------------------------

local function SearchFixture(details)
    local module, HA = LoadModule()
    world.names[555] = "Iron Bar"
    world.currencies[1220] = { name = "Trader's Tender" }
    local vendor = MakeVendor(20)
    world.names[10005] = "Mighty Sword"
    vendor.static[6].cost = { currencies = { { id = 1220, amount = 5 } } }
    vendor.static[7].cost = { items = { { id = 555, amount = 2 } } }
    vendor.static[8].cost = { currencies = { { amount = 3, name = "Old Coin" } } }
    vendor.static[9].cost = { currencies = { { id = 999999, amount = 1, name = "Stored Name" } } }
    vendor.static[10].cost = { currencies = { { id = 999998, amount = 1 } } }
    vendor.static[11].cost = { items = { { amount = 1, name = "NoId Reagent" } } }
    world.names[10012] = nil
    HA.Addon.db.profile.vendorTracer.showVendorPinItemDetails = details
    return OpenVendor(module, HA, vendor)
end

do
    local t = SearchFixture(true)
    local frame, box = t.frame, t.box
    local full = table.concat(RowNames(frame), "|")
    local fullFooter = Footer(frame)
    Check(full:find("Unknown Item", 1, true), "a ware with no name yet shows the fallback")

    box:SetText("mighty")
    Equal(table.concat(RowNames(frame), "|"), full, "nothing renders before the search timer fires")
    FireTimers()
    ExpectNames(frame, { "Mighty Sword" }, "ware name, lower case")
    Search(box, "  mIGHTY  ")
    ExpectNames(frame, { "Mighty Sword" }, "ware name, mixed case and surrounding spaces")
    Check(not t.bar.shown, "one match hides the bar")
    Equal(Footer(frame), fullFooter, "the footer must not change with the search")

    Search(box, "trader's")
    ExpectNames(frame, { "Ware 6" }, "currency name")
    Search(box, "iron bar")
    ExpectNames(frame, { "Ware 7" }, "reagent name")
    Search(box, "old coin")
    ExpectNames(frame, { "Ware 8" }, "currency stored name, no id")
    Search(box, "stored name")
    ExpectNames(frame, { "Ware 9" }, "currency stored name when the client returns nothing")
    Search(box, "noid reagent")
    ExpectNames(frame, {}, "a reagent with no id is skipped")
    Search(box, "ware 12")
    ExpectNames(frame, {}, "a ware with no name does not match yet")

    Search(box, "nonsense")
    ExpectNames(frame, {}, "nonsense query")
    Equal(CountLines(frame, "No items found"), 1, "one no-results line")
    Equal(Footer(frame), fullFooter, "footer unchanged with no results")

    Search(box, "")
    Equal(table.concat(RowNames(frame), "|"), full, "clearing restores the full list at the top")
    Check(t.bar.shown, "clearing the search shows the bar again")

    -- The missing name arrives through the real rebuild path.
    world.names[10012] = "Late Arrival"
    world.eventFrame.scripts.OnEvent(world.eventFrame, "GET_ITEM_INFO_RECEIVED", 10012, true)
    FireTimers()
    Check(table.concat(RowNames(frame), "|"):find("Late Arrival", 1, true), "the rebuild shows the new name")
    Search(box, "late arrival")
    ExpectNames(frame, { "Late Arrival" }, "a ware matches by name once a rebuild supplies it")
end

do
    local t = SearchFixture(false)
    Search(t.box, "trader")
    ExpectNames(t.frame, {}, "with details off a currency name matches nothing")
    Search(t.box, "mighty")
    ExpectNames(t.frame, { "Mighty Sword" }, "with details off the ware name still matches")
end

-------------------------------------------------------------------------------
-- Call counts for scrolling and searching
-------------------------------------------------------------------------------

local function ResetCalls()
    for key in pairs(world.calls) do world.calls[key] = 0 end
end

local GATHER_CALLS = { "GetScannedVendorRecord", "GetItemsForVendor", "GetItemCost", "NormalizeScannedCost", "GetVendorItemCost" }

local function ExpectNoGather(label)
    for _, key in ipairs(GATHER_CALLS) do
        Equal(world.calls[key], 0, label .. ": " .. key)
    end
end

do
    local t = SearchFixture(true)
    world.names[10012] = "Ware 12"
    t.module:ShowVendorTooltip(t.pin, t.vendor)

    ResetCalls()
    Wheel(t.frame, -1)
    ExpectNoGather("wheel step")
    Check(world.calls.GetItemInfo <= 15, "wheel step: GetItemInfo at most 15, got " .. world.calls.GetItemInfo)
    Check(world.calls.GetItemPresentation <= 15, "wheel step: GetItemPresentation at most 15")
    Equal(world.calls.GetVendorStats, 1, "wheel step: GetVendorStats")

    ResetCalls()
    Search(t.box, "ware 1")
    ExpectNoGather("search fire")
    Check(world.calls.GetItemInfo <= 15, "search fire: GetItemInfo at most 15")
    Check(world.calls.GetItemPresentation <= 15, "search fire: GetItemPresentation at most 15")
    Equal(world.calls.GetVendorStats, 1, "search fire: GetVendorStats")
    Equal(world.calls.GetItemNameByID, 0, "search fire: matching resolves no names")
    Equal(world.calls.GetCurrencyInfo, 0, "search fire: matching resolves no currencies")

    ResetCalls()
    Search(t.box, "nonsense")
    for _, key in ipairs({ "GetItemInfo", "GetItemNameByID", "GetCurrencyInfo", "GetItemPresentation", "CreateFromItemID" }) do
        Equal(world.calls[key], 0, "nonsense search: " .. key)
    end
end

-------------------------------------------------------------------------------
-- Close, focus and leave handling
-------------------------------------------------------------------------------

local function AssertClosed(t, label)
    Check(not t.frame.shown, label .. ": the frame must be hidden")
    Check(not t.box.focused, label .. ": the search box must not hold focus")
    Equal(t.box.text, "", label .. ": the search text")
    Equal(PendingTimers(), 0, label .. ": pending timers")
    Check(t.bar.unregisterUpdates >= 1, label .. ": the bar hold must be ended")
end

local function TypeAndFocus(t)
    t.box:SetFocus()
    t.box:SetText("abc")
end

do
    local closes = {
        ["deferred leave, cursor on neither"] = function(t)
            t.frame.scripts.OnLeave(t.frame)
            FireTimers()
        end,
        ["escape"] = function(t)
            TypeAndFocus(t)
            Fire(t.box, "OnEscapePressed")
        end,
        ["focus lost, cursor on neither"] = function(t)
            TypeAndFocus(t)
            t.box:ClearFocus()
        end,
        ["HidePinTooltip"] = function(t)
            TypeAndFocus(t)
            t.module:HidePinTooltip()
        end,
        ["badge tooltip opens"] = function(t)
            TypeAndFocus(t)
            t.module:ShowZoneBadgeTooltip(NewPin("badge"), {
                zoneName = "Zone", vendorCount = 1, collectedItems = 0, totalItems = 0,
                lockedItems = 0, unverifiedItems = 0,
            })
        end,
        ["provider-path close"] = function(t)
            TypeAndFocus(t)
            t.module:CloseInteractiveTooltip()
        end,
        ["direct hide"] = function(t)
            TypeAndFocus(t)
            t.frame:Hide()
        end,
    }
    for label, close in pairs(closes) do
        local t = OpenLong(20)
        close(t)
        AssertClosed(t, label)
        t.frame:Show()
        Check(not t.frame.shown, label .. ": a frame shown with no hover must hide itself")
    end

    local keeps = {
        ["deferred leave, cursor on the tooltip"] = function(t)
            t.frame.mouseOver = true
            t.frame.scripts.OnLeave(t.frame)
            FireTimers()
        end,
        ["deferred leave, cursor on the pin"] = function(t)
            t.pin.mouseOver = true
            t.frame.scripts.OnLeave(t.frame)
            FireTimers()
        end,
        ["focus lost, cursor on the tooltip"] = function(t)
            t.box:SetFocus()
            t.frame.mouseOver = true
            t.box:ClearFocus()
        end,
        ["deferred leave, focus held"] = function(t)
            t.box:SetFocus()
            t.frame.scripts.OnLeave(t.frame)
            FireTimers()
        end,
    }
    for label, act in pairs(keeps) do
        local t = OpenLong(20)
        act(t)
        Check(t.frame.shown, label .. ": the tooltip must stay open")
    end

    -- A pin leave while the interactive tooltip is open defers to the same check.
    local t = OpenLong(20)
    t.module:OnPinLeave()
    Check(t.frame.shown, "a pin leave must wait for the next frame")
    FireTimers()
    AssertClosed(t, "pin leave")

    -- Children of the frame.
    local children = {
        track = function(x) return x.bar.track end,
        thumb = function(x) return x.bar.thumb end,
        back = function(x) return x.bar.back end,
        forward = function(x) return x.bar.forward end,
        box = function(x) return x.box end,
        clearButton = function(x) return x.box.clearButton end,
    }
    for label, get in pairs(children) do
        t = OpenLong(20)
        Fire(get(t), "OnLeave")
        FireTimers()
        AssertClosed(t, label .. " leave, cursor off")

        t = OpenLong(20)
        t.frame.mouseOver = true
        Fire(get(t), "OnLeave")
        FireTimers()
        Check(t.frame.shown, label .. " leave, cursor on the tooltip: must stay open")
    end

    -- A held thumb defers the check to its release.
    t = OpenLong(20)
    local thumb = t.bar.thumb
    Fire(thumb, "OnMouseDown")
    Fire(thumb, "OnLeave")
    FireTimers()
    Check(t.frame.shown, "a thumb drag that strays off the thumb must not close the tooltip")
    Fire(thumb, "OnMouseUp")
    FireTimers()
    AssertClosed(t, "thumb release, cursor off")

    t = OpenLong(20)
    thumb = t.bar.thumb
    Fire(thumb, "OnMouseDown")
    t.frame.mouseOver = true
    Fire(thumb, "OnMouseUp")
    FireTimers()
    Check(t.frame.shown, "a thumb release on the tooltip keeps it open")

    -- The held flag does not survive a forced close.
    t = OpenLong(20)
    Fire(t.bar.thumb, "OnMouseDown")
    t.module:HidePinTooltip()
    t.module:ShowVendorTooltip(t.pin, t.vendor)
    t.frame.scripts.OnLeave(t.frame)
    FireTimers()
    AssertClosed(t, "leave after a forced close mid-drag")

    -- A held thumb whose bar is hidden by a narrowing search.
    t = OpenLong(20)
    Fire(t.bar.thumb, "OnMouseDown")
    local holdsBefore = t.bar.unregisterUpdates
    Search(t.box, "ware 19")
    Check(not t.bar.shown, "one match hides the bar")
    Check(t.bar.unregisterUpdates > holdsBefore, "hiding the bar must end its hold")
    t.frame.scripts.OnLeave(t.frame)
    FireTimers()
    AssertClosed(t, "leave after the bar hid mid-drag")

    -- Stale check: queued for hover A, fired after hover B opened.
    t = OpenLong(20)
    t.frame.scripts.OnLeave(t.frame)
    local pinB = NewPin("pinB")
    t.module:ShowVendorTooltip(pinB, MakeVendor(20))
    FireTimers()
    Check(t.frame.shown, "a leave check from the previous hover must not close the new one")
end

-------------------------------------------------------------------------------
-- Stable placement, late names and fresh opens
-------------------------------------------------------------------------------

do
    local module, HA = LoadModule()
    local pin = NewPin("pinR")
    world.currencies[1220] = { name = "Trader's Tender" }
    local vendor = MakeVendor(16)
    for _, ware in ipairs(vendor.static) do
        ware.cost = { text = "tender", currencies = { { id = 1220, amount = 1, name = "Trader's Tender" } } }
    end
    world.names[10003] = nil
    world.names[10009] = nil
    HA.Addon.db.profile.vendorTracer.showVendorPinItemDetails = true

    module:ShowVendorTooltip(pin, vendor)
    Check(not world.plainCreated, "a long vendor must not create the plain tooltip")
    local frame = FindFrame(INTERACTIVE_NAME)
    local box = FindTemplate("SearchBoxTemplate")
    Equal(frame.counts.SetPoint, 2, "one provisional and one final point per hover")
    Equal(frame.counts.SetOwner, 1, "one owner per hover")

    Search(box, "tender")
    Equal(#RowNames(frame), 15, "all 16 wares match the shared currency, unnamed ones included")
    Wheel(frame, -1)
    box:SetFocus()
    local snapshot = table.concat(RowNames(frame), "|")
    Check(snapshot:find("Unknown Item", 1, true), "unnamed wares show the fallback")
    Equal(frame.counts.SetPoint, 2, "no point change during scroll or search")

    local function Rebuild(drive)
        local gathers = world.calls.GetItemsForVendor
        local counts = {
            SetOwner = frame.counts.SetOwner, ClearAllPoints = frame.counts.ClearAllPoints,
            SetPoint = frame.counts.SetPoint,
        }
        drive()
        FireTimers()
        Equal(world.calls.GetItemsForVendor, gathers + 1, "the rebuild gathers once more")
        for method, count in pairs(counts) do
            Equal(frame.counts[method], count, "no " .. method .. " during a rebuild")
        end
        Equal(box.text, "tender", "search text survives a rebuild")
        Check(box.focused, "focus survives a rebuild")
        Check(frame.shown, "the tooltip survives a rebuild")
    end

    world.names[10003] = "Late Name"
    Rebuild(function()
        world.eventFrame.scripts.OnEvent(world.eventFrame, "GET_ITEM_INFO_RECEIVED", 10003, true)
    end)
    local rows = RowNames(frame)
    Equal(rows[1], "Ware 2", "scroll position survives a rebuild")
    Check(table.concat(rows, "|"):find("Late Name", 1, true), "the rebuild shows the new name in place")

    world.names[10009] = "Second Late Name"
    Check(world.loadCallbacks[10009], "the unnamed ware must have requested its data")
    Rebuild(function() world.loadCallbacks[10009]() end)
    Check(table.concat(RowNames(frame), "|"):find("Second Late Name", 1, true), "the load callback shows the new name")

    -- A second pin enter is a fresh open.
    module:ShowVendorTooltip(pin, vendor)
    ExpectNames(frame, (function()
        local names = {}
        for index = 1, 15 do names[index] = world.names[10000 + index] or "Unknown Item" end
        return names
    end)(), "a second pin enter starts at the top")
    Equal(box.text, "", "a second pin enter empties the search box")
    Check(not box.focused, "a second pin enter drops focus")
    Equal(frame.counts.SetPoint, 4, "two points per hover")

    -- A zero first width: one retry, and scrolling in between stays within the window.
    module:HidePinTooltip()
    frame.width = 0
    module:ShowVendorTooltip(pin, vendor)
    Equal(PendingTimers(), 1, "a zero first width schedules exactly one retry")
    Wheel(frame, -1)
    Check(#RowNames(frame) <= 15, "a scroll step before the retry renders at most 15 rows")
    Equal(PendingTimers(), 1, "scrolling schedules no further retry")
    Equal(frame.counts.SetPoint, 5, "the frame keeps its provisional point until a width is real")
    frame.width = 320
    FireTimers()
    Equal(PendingTimers(), 0, "the retry fires once")
    Equal(frame.counts.SetPoint, 6, "the retry places the frame")
end

-------------------------------------------------------------------------------
-- Width: the full list's own width plus one bar column, the same in every state
-------------------------------------------------------------------------------

do
    local MARGINS, BAR_COLUMN = 20, 24

    -- A wrapped line folds to the width the other lines set; it never sets one.
    local function Content(frame)
        local widest = 0
        for _, line in ipairs(frame.lines) do
            if not line.wrap then
                widest = math.max(widest, 20 * (#(line.left or "") + #(line.right or "")))
            end
        end
        return widest
    end

    -- The two ways a client could count a minimum width: over the text alone,
    -- or over the whole frame with its margins and padding.
    local models = {
        ["minimum counts text only"] = function(frame)
            return math.max(Content(frame), frame.minWidth or 0) + MARGINS + frame.padding[1]
        end,
        ["minimum counts the whole frame"] = function(frame)
            return math.max(Content(frame) + MARGINS + frame.padding[1], frame.minWidth or 0)
        end,
    }

    for label, model in pairs(models) do
        local module, HA = LoadModule()
        local vendor = MakeVendor(20)
        world.names[10020] = "Ware 20 with the longest name on the list"
        -- The frame exists after the first open; give it a width model, then open again.
        local t = OpenVendor(module, HA, vendor)
        module:HidePinTooltip()
        t.frame.widthModel = model
        module:ShowVendorTooltip(t.pin, vendor)

        local widestRow = 20 * (#"  Ware 20 with the longest name on the list" + #"cost 20")
        local expected = widestRow + MARGINS + BAR_COLUMN
        Check(Content(t.frame) < widestRow, label .. ": the first window must not hold the widest row")
        Equal(t.frame:GetWidth(), expected, label .. ": open is the full list's width plus the bar column")
        Wheel(t.frame, -5)
        Equal(t.frame:GetWidth(), expected, label .. ": scrolling to the widest row keeps the width")
        Search(t.box, "ware 1")
        Check(#RowNames(t.frame) <= 15 and not t.bar.shown, label .. ": the search must hide the bar")
        Equal(t.frame.padding[1], BAR_COLUMN, label .. ": the bar column stays reserved when the bar hides")
        Equal(t.frame:GetWidth(), expected, label .. ": the width holds when the bar hides")
        Search(t.box, "")
        Equal(t.frame:GetWidth(), expected, label .. ": clearing the search keeps the width")
    end

    -- Footer text longer than every ware row wraps on the long tooltip and leaves the width to the rows.
    local longBlocker = "Achievement: a requirement name far longer than any ware row on this list"
    local footerProps = {
        opposite = true,
        stats = {
            total = 20, collected = 0, locked = 5, unverified = 0, vendorOnly = 2,
            blockers = {
                { label = longBlocker, count = 2 }, { label = "Quest", count = 1 },
                { label = "Renown", count = 1 }, { label = "Reputation", count = 1 },
            },
        },
    }
    local footerLines = {
        "Vendor-only: 2",
        "Cannot buy on this character - opposite faction vendor",
        "Locked counts above only reflect requirement gates.",
        "Locked by: " .. longBlocker .. " (2)",
        "Locked by: Quest (1)",
        "Locked by: Renown (1)",
        "Locked by: +1 more blocker types",
        "Left-click to set waypoint (for alts)",
    }

    local function ExpectFooterWrap(frame, wrapped, label)
        for _, text in ipairs(footerLines) do
            local found
            for _, line in ipairs(frame.lines) do
                if line.left == text then found = line end
            end
            Check(found, label .. ": footer line present: " .. text)
            Equal(found.wrap == true, wrapped, label .. ": wrap on footer line: " .. text)
        end
    end

    for label, model in pairs(models) do
        local module, HA = LoadModule()
        local vendor = MakeVendor(20, footerProps)
        local t = OpenVendor(module, HA, vendor)
        module:HidePinTooltip()
        -- The measuring read is the one taken under the 240 floor.
        local footerMeasured = false
        t.frame.widthModel = function(frame)
            if frame.minWidth == 240 and CountLines(frame, footerLines[4]) > 0 then footerMeasured = true end
            return model(frame)
        end
        module:ShowVendorTooltip(t.pin, vendor)
        Check(not footerMeasured, label .. ": the measuring pass must hold no footer line")

        -- The header's faction warning is the widest line above the footer here.
        local widestKept = 20 * #"Cannot access - opposite faction vendor"
        Check(20 * #footerLines[4] > widestKept, label .. ": the blocker line must be wider than the header and every ware row")
        local expected = widestKept + MARGINS + BAR_COLUMN
        ExpectFooterWrap(t.frame, true, label)
        Equal(t.frame:GetWidth(), expected, label .. ": a long footer line leaves the width to the ware rows")
        Wheel(t.frame, -5)
        Equal(t.frame:GetWidth(), expected, label .. ": scrolling keeps the ware-row width")
        Search(t.box, "ware 1")
        ExpectFooterWrap(t.frame, true, label .. ", searched")
        Equal(t.frame:GetWidth(), expected, label .. ": a bar-hiding search keeps the ware-row width")
        Search(t.box, "")
        Equal(t.frame:GetWidth(), expected, label .. ": clearing keeps the ware-row width")
        world.names[10003] = "Ware 3"
        world.eventFrame.scripts.OnEvent(world.eventFrame, "GET_ITEM_INFO_RECEIVED", 10003, true)
        FireTimers()
        Equal(t.frame:GetWidth(), expected, label .. ": an item arrival keeps the ware-row width")
    end

    -- The same footer on a short vendor: no line asks to wrap.
    local module = LoadModule()
    module:ShowVendorTooltip(NewPin("pinW"), MakeVendor(15, footerProps))
    ExpectFooterWrap(FindFrame(PLAIN_NAME), false, "plain tooltip")
end

-------------------------------------------------------------------------------
-- Anchoring in screen pixels
-------------------------------------------------------------------------------

do
    local function Anchor(pinProps, frameProps)
        local module = LoadModule()
        local pin = NewPin("pinG", pinProps)
        -- The frame exists after the first open; set its geometry, then open again.
        module:ShowVendorTooltip(pin, MakeVendor(20))
        local frame = FindFrame(INTERACTIVE_NAME)
        module:HidePinTooltip()
        for key, value in pairs(frameProps or {}) do frame[key] = value end
        module:ShowVendorTooltip(pin, MakeVendor(20))
        local point = frame.points[#frame.points]
        return point[1], point[3], pin, point[2]
    end

    local point, relative, pin, relTo = Anchor({ right = 100, top = 600 }, { width = 320, height = 300 })
    Equal(point .. ">" .. relative, "TOPLEFT>TOPRIGHT", "room on the right and below")
    Check(relTo == pin, "anchored to the pin")

    point, relative = Anchor({ right = 1800, top = 600 }, { width = 320, height = 300 })
    Equal(point .. ">" .. relative, "TOPRIGHT>TOPLEFT", "no room on the right")

    point, relative = Anchor({ right = 100, top = 100 }, { width = 320, height = 300 })
    Equal(point .. ">" .. relative, "BOTTOMLEFT>BOTTOMRIGHT", "not fitting below")

    point, relative = Anchor({ right = 1800, top = 100 }, { width = 320, height = 300 })
    Equal(point .. ">" .. relative, "BOTTOMRIGHT>BOTTOMLEFT", "neither right nor below")

    -- Unequal scales: ignoring them would flip and hang down the other way.
    point, relative = Anchor({ right = 3000, top = 400, scale = 0.5 }, { width = 320, height = 300, scale = 1 })
    Equal(point .. ">" .. relative, "BOTTOMLEFT>BOTTOMRIGHT", "scaled pin: room to the right, none below")
end

-------------------------------------------------------------------------------
-- Item arrivals that cannot affect the open tooltip
-------------------------------------------------------------------------------

do
    local t = SearchFixture(true)
    local function Arrive(itemID)
        world.eventFrame.scripts.OnEvent(world.eventFrame, "GET_ITEM_INFO_RECEIVED", itemID, true)
    end

    local gathers = world.calls.GetItemsForVendor
    Arrive(424242)
    Equal(PendingTimers(), 0, "an unrelated arrival must not queue a rebuild")
    FireTimers()
    Equal(world.calls.GetItemsForVendor, gathers, "an unrelated arrival must not gather")

    Arrive(10003)
    Equal(PendingTimers(), 1, "a ware arrival queues a rebuild")
    FireTimers()
    Equal(world.calls.GetItemsForVendor, gathers + 1, "a ware arrival rebuilds")

    Arrive(555)
    Equal(PendingTimers(), 1, "a reagent cost arrival queues a rebuild")
    FireTimers()
    Equal(world.calls.GetItemsForVendor, gathers + 2, "a reagent cost arrival rebuilds")

    Arrive(nil)
    Equal(PendingTimers(), 1, "an arrival with no item id queues a rebuild")
    FireTimers()
    Check(t.frame.shown, "the tooltip survives the rebuilds")

    local module = LoadModule()
    module:ShowVendorTooltip(NewPin("pinS"), MakeVendor(5))
    Arrive(424242)
    Equal(PendingTimers(), 1, "an unrelated arrival still rebuilds the short tooltip")
end

print("hs493_pin_tooltip_scroll_search: ok")
