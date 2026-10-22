-- luacheck: globals assert loadfile print rawset
local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The Events page and shop page against the real holiday gate: the real Data files,
-- VendorFilter and the browser Adapter, with only the calendar and price source stubbed.
-------------------------------------------------------------------------------

rawset(_G, "C_NeighborhoodInitiative", { GetNeighborhoodInitiativeInfo = function() return nil end })
rawset(_G, "C_Item", { GetItemNameByID = function(id) return "Item" .. id end })
rawset(_G, "UnitFactionGroup", function() return "Horde" end)
rawset(_G, "GetBuildInfo", function() return "12.0.1", "1", "1", 120001 end)

local HA = {
    Addon = { db = {
        profile = { vendorTracer = { showEventVendors = true } },
        global = { discoveredInitiativeThemes = {}, scannedVendors = {}, noDecorVendors = {} },
    }, Debug = function() end, RegisterModule = function() end },
    Events = { Fire = function() end, RegisterCallback = function() end },
    Constants = { ZoneToFactionMap = {}, TEXTURE_ROOT = "Textures/" },
    DecorMapping = {},
}
local calendar = nil
HA.CalendarDetector = { IsHolidayActive = function(_, name)
    if not name or calendar == nil then return nil end
    return calendar[name] == true
end }
local priced = {}
HA.SourceManager = { GetVendorItemCost = function(_, itemID, vendor)
    priced[#priced + 1] = vendor and vendor.npcID
    return vendor and { gold = vendor.npcID * 1000 + itemID } or nil
end }
HA.CatalogStore = { HasPersistedData = function() return true end, IsOwned = function() return false end,
    IsOwnershipUnknowable = function() return false end }

for _, f in ipairs({ "Locale/enUS.lua", "Data/VendorIdentity.lua", "Data/VendorOffers.lua", "Data/VendorData.lua",
    "Data/EndeavorsData.lua", "Data/EventSources.lua", "UI/VendorFilter.lua", "UI/Browser/Style.lua",
    "UI/Browser/Adapter.lua" }) do
    assert(loadfile(root .. "/" .. f))("Homestead", HA)
end
HA.VendorData:BuildOfferIndexes()
local D, VD = HA.DecorBrowser.Data, HA.VendorData
VD.FormatCost = function(_, cost) return "cost" .. cost.gold end
local ECHO, VALADAR = 273402, 15864

local function tags()
    local out = {}
    for _, r in ipairs(D.SourceList("events", "", false)) do
        if r.kind == "vendor" then out[r.vendor.npcID] = r.active end
    end
    return out
end

-- Running, not running and unknown calendar: the vendor is always listed; only the tag changes.
for state, want in pairs({ running = true, off = false, unknown = false }) do
    calendar = state == "running" and { ["Hallow's End"] = true, ["Lunar Festival"] = true }
        or state == "off" and {} or nil
    local t = tags()
    assert(t[ECHO] == want and t[VALADAR] == want, state .. ": Echo/Valadar tag should be " .. tostring(want))
    assert(D.HolidayActive(D.HolidayVendor(ECHO)) == want)
    assert(D.IsListedVendor(D.HolidayVendor(ECHO)) == want, state .. ": other surfaces list it only in season")
    local expansion = D.HolidayVendor(ECHO).expansion
    if expansion then
        local listed = false
        for _, v in ipairs(D.VendorsByExpansion(expansion)) do listed = listed or v.npcID == ECHO end
        assert(listed == want, state .. ": Vendors by expansion")
    end
end

-- Shop page reads: the same record, items and prices in and out of season.
calendar = { ["Hallow's End"] = true }
local active = D.Vendor(ECHO)
assert(active and #active.items > 0, "the real Echo record has wares")
local ware = D.VendorWares(active)[1]
local activePrice = D.Price(ware, D.Vendor(ECHO))
calendar = {}
assert(VD:GetVendor(ECHO) == nil, "the real gate hides Echo out of season")
local idle = D.Vendor(ECHO)
assert(idle and idle.name == active.name and #idle.items == #active.items, "Not Active shop data matches Active")
assert(activePrice == "cost" .. (ECHO * 1000 + ware), "the price comes from the vendor record: " .. tostring(activePrice))
assert(D.Price(ware, D.Vendor(ECHO)) == activePrice, "prices populate the same")
assert(D.VendorWares(idle)[1] == D.VendorWares(active)[1], "wares match")
assert(D.Vendor(ECHO) ~= HA.EventSources.EventVendors[ECHO], "a copy, never the data table")

-- Counts: the background fill never covers an out-of-season holiday vendor, so the browser computes
-- them in deferred, out-of-combat steps (one vendor per tick, one refresh at the end) and never asks
-- for a fill it cannot satisfy.
do
    local prewarms, timers, refreshes, inCombat, gen = 0, {}, 0, false, 1
    local cache, computed, measured = {}, {}, {}
    HA.BadgeCalculation = {
        PeekVendorStats = function(_, v) return cache[v.npcID] end,
        GetVendorStats = function(_, v)
            computed[#computed + 1] = v.npcID
            cache[v.npcID] = { collected = 3, total = 3 }
            return cache[v.npcID]
        end,
        RequestPrewarm = function() prewarms = prewarms + 1 end,
    }
    HA.PerformanceTrace = { Measure = function(_, op, _, fn, ...) measured[#measured + 1] = op return fn(...) end }
    rawset(_G, "C_Timer", { After = function(_, fn) timers[#timers + 1] = fn end })
    rawset(_G, "InCombatLockdown", function() return inCombat end)
    HA.DecorBrowser.RequestRefresh = function() refreshes = refreshes + 1 end
    HA.DecorBrowser.Generation = function() return gen end
    local function tick() table.remove(timers, 1)() end
    calendar = {}
    local echo, jack = D.HolidayVendor(ECHO), D.HolidayVendor(273403)

    for _ = 1, 3 do assert(D.VendorCounts(echo, false) == nil) end
    assert(prewarms == 0, "no fill is requested for a vendor the fill cannot cover")
    assert(#timers == 1 and #computed == 0, "one deferred step, nothing computed synchronously")

    -- Combat and a changed page both drop the queue and un-mark, computing nothing.
    inCombat = true
    tick()
    assert(#computed == 0 and refreshes == 0 and #timers == 0, "nothing runs in combat")
    inCombat = false
    assert(D.VendorCounts(echo, false) == nil and #timers == 1, "un-marked, so the next render asks again")
    gen = 2
    tick()
    assert(#computed == 0 and refreshes == 0 and #timers == 0, "a page or window change before the tick computes nothing")
    gen = 3

    -- Two vendors: one per tick, one refresh at the end, measured under the browser's operation name.
    assert(D.VendorCounts(echo, false) == nil and D.VendorCounts(jack, false) == nil and #timers == 1)
    tick()
    assert(#computed == 1 and refreshes == 0 and #timers == 1, "one vendor per tick")
    tick()
    assert(#computed == 2 and refreshes == 0 and #timers == 1)
    tick()
    assert(refreshes == 1 and #timers == 0, "a single refresh at the end")
    assert(measured[1] == "browser_holiday_counts" and #measured == 2)

    -- A vendor queued after the last compute, before the final empty tick, joins the same chain.
    D.InvalidateMemos()
    cache = {}
    computed, refreshes = {}, 0
    assert(D.VendorCounts(echo, false) == nil and #timers == 1)
    tick()
    assert(#computed == 1 and #timers == 1, "last compute done, the empty tick is pending")
    assert(D.VendorCounts(jack, false) == nil and #timers == 1, "still one pending timer, no second chain")
    tick()
    assert(#computed == 2 and refreshes == 0 and #timers == 1, "the late vendor runs on the next tick, alone")
    tick()
    assert(refreshes == 1 and #timers == 0, "one refresh in total")
    cache = {}
    cache[ECHO] = { collected = 3, total = 3 }

    local owned, total = D.VendorCounts(echo, false)
    assert(owned == 3 and total == 3, "counts are there after the deferred steps")
    local found = false
    for _, row in ipairs(D.SourceList("events", "", false)) do found = found or (row.kind == "vendor" and row.vendor.npcID == ECHO) end
    assert(found, "without Hide owned the vendor is listed")
    for _, row in ipairs(D.SourceList("events", "", true)) do
        assert(not (row.kind == "vendor" and row.vendor.npcID == ECHO), "Hide owned removes it")
    end
    assert(prewarms == 0)
    assert(D.VendorCounts({ npcID = 1 }, false) == nil and prewarms == 1, "a vendor the fill covers still asks for it")
end

print("hs534_browser_holiday: ok")
