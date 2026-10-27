-- luacheck: globals assert loadfile print tonumber C_Item C_Timer C_AddOns CreateFrame GetMerchantItemLink KrowiEVU MerchantFrame MERCHANT_ITEMS_PER_PAGE

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_AddOns = { IsAddOnLoaded = function(name) return name == "Krowi_ExtendedVendorUI" end }

local eventFrames = {}
CreateFrame = function()
    local f = { scripts = {} }
    function f:RegisterEvent() end
    function f:UnregisterAllEvents() end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    eventFrames[#eventFrames + 1] = f
    return f
end

MERCHANT_ITEMS_PER_PAGE = 10
MerchantFrame = { page = 1, selectedTab = 1 }

local links = {}
for i = 1, 40 do links[i] = "item:" .. (5000 + i) end
GetMerchantItemLink = function(index) return links[index] end
C_Item = { GetItemInfoInstant = function(link) return tonumber(link:match("item:(%d+)")) end }

-- Records which item the marker was painted for, per overlay.
local overlays, painted, cleared = {}, {}, {}
local Overlay = {
    externalRefreshers = {},
    AddToFrame = function(self, button, updateFunc)
        local o = { button = button }
        button.HousingAddonOverlay = o
        overlays[#overlays + 1] = o
        o.updateFunc = updateFunc
        if updateFunc then updateFunc(o) end
        return o
    end,
    ClearIcon = function(_, o) cleared[o] = (cleared[o] or 0) + 1; painted[o] = nil end,
    SetHomestoneState = function(_, o, status) painted[o] = status end,
    RegisterExternalRefresher = function(self, key, fn) self.externalRefreshers[key] = fn end,
}

local HA = {
    Overlay = Overlay,
    Events = { RegisterCallback = function() end },
    CatalogStore = { IsDecorItem = function() return true end },
    SourceManager = { GetMerchantItemStatus = function(_, itemID) return "item" .. itemID end },
    Addon = {
        Debug = function() end,
        db = { profile = { overlay = { enabled = true, showOnMerchant = true } } },
    },
}

assert(loadfile(root .. "/Overlay/Merchant.lua"))("Homestead", HA)
assert(Overlay.Merchant and Overlay.Merchant.UpdateButton, "Merchant must expose UpdateButton")

-- Stock path: run Merchant's deferred Initialize, then show the merchant.
local nTimers = #timers
for i = 1, nTimers do timers[i]() end
local stockFrame
for _, f in ipairs(eventFrames) do if f.scripts.OnEvent then stockFrame = f end end
local stockButtons = {}
for i = 1, 10 do
    stockButtons[i] = { id = i, GetID = function(self) return self.id end }
    rawset(_G, "MerchantItem" .. i .. "ItemButton", stockButtons[i])
end
MerchantFrame.HookScript = function() end
MerchantFrame.page = 2
stockFrame.scripts.OnEvent(stockFrame, "MERCHANT_SHOW")
-- Blizzard sets GetID to the real merchant index per page; closure must not offset it again.
for i = 1, 10 do
    local b = stockButtons[i]
    b.id = 10 + i
    b.HousingAddonOverlay.updateFunc(b.HousingAddonOverlay)
    assert(painted[b.HousingAddonOverlay] == "item" .. (5000 + 10 + i),
        "page 2 slot " .. i .. " painted for " .. tostring(painted[b.HousingAddonOverlay]))
end

-- No Krowi global: loading the module registers nothing and does not error.
KrowiEVU = nil
timers = {}
assert(loadfile(root .. "/Overlay/KrowiEVU.lua"))("Homestead", HA)
for i = 1, #timers do timers[i]() end
assert(Overlay.externalRefreshers.krowiEVU == nil, "must stay inert without Krowi")

-- Krowi present at load time.
local registered = {}
KrowiEVU = { PluginsApi = { RegisterPlugin = function(_, name, plugin) registered[name] = plugin end } }
timers = {}
assert(loadfile(root .. "/Overlay/KrowiEVU.lua"))("Homestead", HA)
for i = 1, #timers do timers[i]() end
local plugin = assert(registered.Homestead, "plugin must register as Homestead")
assert(Overlay.externalRefreshers.krowiEVU, "refresher must be registered")

local function newSlot(id)
    return {
        shown = true,
        IsShown = function(self) return self.shown end,
        ItemButton = { id = id, GetID = function(self) return self.id end },
    }
end

local slot = newSlot(23)
plugin:OnItemSlotUpdated(slot, 23)
local overlay = slot.ItemButton.HousingAddonOverlay
assert(painted[overlay] == "item5023", "slot must paint for the real index")

-- Ownership repaint reads the slot's current index.
slot.ItemButton.id = 24
Overlay.externalRefreshers.krowiEVU()
assert(painted[overlay] == "item5024", "refresher must repaint a shown slot")

-- Hidden slots are skipped.
slot.shown = false
slot.ItemButton.id = 25
Overlay.externalRefreshers.krowiEVU()
assert(painted[overlay] == "item5024", "hidden slot must not repaint")
slot.shown = true

-- Empty slot clears; buyback tab clears.
plugin:OnItemSlotUpdated(slot, nil)
assert(painted[overlay] == nil, "nil index must clear")
plugin:OnItemSlotUpdated(slot, 3)
assert(painted[overlay] == "item5003")
MerchantFrame.selectedTab = 2
plugin:OnItemSlotUpdated(slot, 3)
assert(painted[overlay] == nil, "buyback tab must clear")
MerchantFrame.selectedTab = 1

-- Empty slot with no overlay yet creates nothing.
local empty = newSlot(0)
local before = #overlays
plugin:OnItemSlotUpdated(empty, nil)
assert(#overlays == before, "empty slot must not allocate an overlay")

-- Settings off clears.
HA.Addon.db.profile.overlay.showOnMerchant = false
plugin:OnItemSlotUpdated(slot, 3)
assert(painted[overlay] == nil, "disabled setting must clear")

-- Late load: global appears only at Krowi's ADDON_LOADED; double events register once.
registered = {}
Overlay.externalRefreshers.krowiEVU = nil
KrowiEVU = nil
C_AddOns.IsAddOnLoaded = function() return false end
timers = {}
eventFrames = {}
assert(loadfile(root .. "/Overlay/KrowiEVU.lua"))("Homestead", HA)
for i = 1, #timers do timers[i]() end
local waiter = eventFrames[#eventFrames]
assert(waiter and waiter.scripts.OnEvent and not registered.Homestead)
waiter.scripts.OnEvent(waiter, "ADDON_LOADED", "SomeOtherAddon")
assert(not registered.Homestead)
KrowiEVU = { PluginsApi = { RegisterPlugin = function(_, name, p) registered[name] = (registered[name] and error("double register")) or p end } }
waiter.scripts.OnEvent(waiter, "ADDON_LOADED", "Krowi_ExtendedVendorUI")
assert(registered.Homestead and Overlay.externalRefreshers.krowiEVU)

print("krowi_evu_plugin: all checks passed")
