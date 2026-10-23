-- luacheck: globals assert loadfile print io os CreateFrame UIParent C_Texture PixelUtil CreateColor C_ColorOverrides
-- luacheck: globals CreateScrollBoxListLinearView ScrollUtil CreateAnchor CreateDataProvider TextSizeManager NineSliceUtil
-- luacheck: globals C_Item C_HousingCatalog C_Map Enum InCombatLockdown GetBuildInfo wipe NORMAL_FONT_COLOR rawset
-- Run from the repo root:  lua tests/hs538_item.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The item detail: states come from the vendor offer (never a buy state from
-- the presentation), the page runs head, state, flags, requires, sources and
-- Report in that order with open sources first, vendor blocks use gold labels
-- with white values, every Show button calls the one key builder, the faction
-- tag never reaches a format string as nil, Report is off in combat, a redraw
-- never walks, and no red appears outside the faction state on the page or
-- in the tooltip.
-------------------------------------------------------------------------------

local function noop() end
local Widget
local frames, made = {}, {}
local methods = {}
function methods.CreateFontString(self, _, _, font)
    local fs = Widget("FontString")
    fs.font = font
    made[#made + 1] = fs
    return fs
end
function methods.CreateTexture() return Widget("Texture") end
function methods.SetFontObject(self, font) self.font = font end
function methods.SetText(self, text) self.text = text end
function methods.GetText(self) return self.text end
function methods.SetWidth(self, w) self.width = w end
function methods.GetWidth(self) return rawget(self, "width") or 0 end
function methods.SetSize(self, w, h) self.width, self.height = w, h end
function methods.SetHeight(self, h) self.height = h end
function methods.GetHeight(self) return rawget(self, "height") or 24 end
function methods.SetShown(self, on) self.shown = on end
function methods.Show(self) self.shown = true end
function methods.Hide(self) self.shown = false end
function methods.IsShown(self) return self.shown end
function methods.SetEnabled(self, on) self.enabled = on end
function methods.IsEnabled(self) return self.enabled end
function methods.SetMotionScriptsWhileDisabled(self, on) self.motion = on end
-- The engine's gate: a disabled button runs no OnEnter unless its motion scripts are on.
local function Enter(f)
    if f:IsEnabled() or rawget(f, "motion") then f.scripts.OnEnter(f) end
end
function methods.SetScript(self, name, fn) self.scripts[name] = fn end
function methods.HookScript(self, name, fn) self.scripts[name] = fn end
function methods.SetAlpha(self, a) self.alpha = a end
function methods.SetDesaturated(self, on) self.desaturated = on end
function methods.SetTextColor(self, r, g, b) self.color = { r, g, b } end
function methods.SetVertexColor(self, r, g, b) self.color = { r, g, b } end
function methods.SetColorTexture(self, r, g, b) self.color = { r, g, b } end
function methods.GetUnboundedStringWidth(self) return #self.text * 6 end
function methods.GetStringHeight() return 12 end
function methods.GetTextWidth(self) return #self.text * 6 end
function methods.GetFrameLevel() return 1 end
function methods.GetParent(self) return self.parent end
function methods.SetPoint(self, ...) self.pt = { ... } end
function methods.SetOwner(self, owner) self.owner = owner end
function methods.GetOwner(self) return self.owner end
function methods.AddLine(self, text, r, g, b) self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b } end
function methods.AddDoubleLine(self, a, b2) self.lines[#self.lines + 1] = { text = a .. " " .. b2 } end
function Widget(kind)
    return setmetatable({ kind = kind, shown = true, enabled = true, text = "", scripts = {}, lines = {} }, {
        __index = function(_, k) return methods[k] or (k:match("^%u") and noop or nil) end,
    })
end

UIParent = Widget("UIParent")
CreateFrame = function(kind, _, parent)
    local w = Widget(kind)
    w.parent = parent
    frames[#frames + 1] = w
    return w
end
C_Texture = { GetAtlasInfo = function() return nil end }
PixelUtil = { SetHeight = noop, SetWidth = noop }
NineSliceUtil = { ApplyLayoutByName = noop }
CreateColor = function() return {} end
CreateAnchor = noop
CreateDataProvider = function(t) return t end
TextSizeManager = { GetScale = function() return 1 end }
local qualityColor = { r = 0, g = 0.5, b = 1 }
C_ColorOverrides = { GetColorForQuality = function() return qualityColor end }
ScrollUtil = { InitScrollBoxListWithScrollBar = noop, AddManagedScrollBarVisibilityBehavior = noop }
CreateScrollBoxListLinearView = function() return Widget("View") end
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
Enum = { UIMapType = { Zone = 3, Continent = 2 } }
local inCombat = false
InCombatLockdown = function() return inCombat end
GetBuildInfo = function() return "12.0.1", "1", "1", 120001 end
rawset(_G, "wipe", function(t) for k in pairs(t) do t[k] = nil end return t end)
rawset(_G, "ITEM_QUALITY3_DESC", "Rare")

-- Game data -------------------------------------------------------------------
local phase = "ready"
local OWNED = {}
local INFO = {}
local NAMES = {}
C_Item = {
    GetItemNameByID = function(id) return NAMES[id] end,
    RequestLoadItemDataByID = noop,
    GetItemIconByID = function() return 134400 end,
    GetItemQualityByID = function() return 3 end,
}
C_HousingCatalog = {
    GetCatalogEntryInfoByItem = function(id) return INFO[id] end,
    GetCatalogEntryInfoByRecordID = function() return nil end,
}
C_Map = {
    GetBestMapForUnit = function() return 100 end,
    GetMapInfo = function(id) return { mapType = 3, parentMapID = 0, name = "Map " .. tostring(id) } end,
    GetMapChildrenInfo = function() return {} end,
}

local VENDOR, RECORDS = {}, {}
local SOURCES = {}
local REQS = {}
local OFFER = {}
local OPPOSITE, FACTION_LABEL = {}, {}
local inSeason = true
local walks, waypoints, reports, presentations = 0, {}, {}, 0

local HA = {
    Constants = { TEXTURE_ROOT = "Textures/", VERSION = "9.9.9" },
    CatalogScanner = {
        HasFirstReadCompleted = function() return phase ~= "counting" end,
        HasFirstReadAttempted = function() return phase == "notRead" end,
        IsWarm = function() return phase == "ready" end,
    },
    CatalogStore = {
        IsOwnershipUnknowable = function() return false end,
        IsOwned = function(_, id) return OWNED[id] == true end,
        ComputeOwnedFromInfo = function(_, info) return info.owned == true end,
        HasPersistedData = function() return false end,
        GetDecorIDFromItemID = function() return nil end,
    },
    SourceManager = {
        GetAllSources = function(_, id) return SOURCES[id] end,
        GetVendorItemAvailabilityState = function(_, id, npcID) return OFFER[npcID] or "purchasable" end,
        GetRequirements = function(_, id, npcID)
            local r = REQS[id]
            if type(r) == "function" then return r(npcID) end
            return r
        end,
        IsRequirementMet = function(_, r) return r.met end,
        GetVendorItemCost = function() return { gold = 100 } end,
        GetItemPresentation = function() presentations = presentations + 1 return nil end,
    },
    VendorData = {
        GetVendor = function(_, npcID) return VENDOR[npcID] end,
        FormatCost = function() return "1g" end,
        HasOfferForItem = function() return nil end,
        GetScannedVendorRecord = function(_, v) return RECORDS[v.npcID] end,
        GetVendorItems = function() return {} end,
    },
    VendorFilter = {
        CanAccessVendor = function(v) return not OPPOSITE[v.npcID] end,
        IsOppositeFaction = function(v) return OPPOSITE[v.npcID] == true end,
        GetEffectiveFaction = function(v) return FACTION_LABEL[v.npcID] end,
        GetBestVendorCoordinates = function(v) return { x = 0.5, y = 0.5 }, v.mapID end,
        ShouldRevealUnreleasedVendors = function() return true end,
    },
    EventSources = { EventVendors = {} },
    CalendarDetector = { IsHolidayActive = function(_, name) return name == "Midsummer" and inSeason end },
    PerformanceTrace = { Measure = function(_, _, _, fn, ...) return fn(...) end },
    Waypoints = { Set = function(_, ...) waypoints[#waypoints + 1] = { ... } end },
    OutputWindow = { Show = function(_, title, text) reports[#reports + 1] = { title = title, text = text } end },
    DecorMapping = {},
    Addon = { db = { global = {}, profile = {} } },
}
assert(loadfile(root .. "/Locale/enUS.lua"))("Homestead", HA)
for _, file in ipairs({ "Style", "Visuals", "Widgets", "Adapter", "Facts" }) do
    assert(loadfile(root .. "/UI/Browser/" .. file .. ".lua"))("Homestead", HA)
end
local B = HA.DecorBrowser
B.Window = { AddSearchBox = noop }
assert(loadfile(root .. "/UI/Browser/CanGet.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/Browser/Browser.lua"))("Homestead", HA)
assert(loadfile(root .. "/UI/Browser/Item.lua"))("Homestead", HA)
local S, D, CG, K = B.Style, B.Data, B.CanGet, B.Style.color
local Item = B.ItemDetail

local routed = {}
B.Go = function(route) routed[#routed + 1] = route end
local realWalk = CG.Walk
CG.Walk = function(...)
    walks = walks + 1
    return realWalk(...)
end

local function vendor(npcID, name, extra)
    local v = { npcID = npcID, name = name, zone = "Elwynn Forest", mapID = 100 }
    for k, val in pairs(extra or {}) do v[k] = val end
    VENDOR[npcID] = v
    return v
end
local function vsrc(v)
    return { type = "vendor", data = { npcID = v.npcID, name = v.name, zone = v.zone, vendor = v, cost = { gold = 100 } } }
end

local function fresh(id, info)
    INFO[id] = info or { quality = 3, categoryIDs = { 1 }, totalNumPlaced = 0, totalNumStored = 0 }
    NAMES[id] = "Item " .. id
    D.InvalidateMemos()
    B.State.catalogMemo = {}
end

local function show(id)
    local ok, err = pcall(function()
        Item.Build(Widget("Frame"))
        Item.Show(id)
    end)
    assert(ok, "Show failed: " .. tostring(err))
    local list = {}
    for _, fr in ipairs(frames) do
        local y = fr.shown and fr.pt and fr.pt[5] and -fr.pt[5]
        if y and fr.mark then
            list[#list + 1] = { y = y, text = fr.text.text, color = fr.text.color, glyph = rawget(fr.mark, "glyph") }
        elseif y and fr.kind == "Button" and fr.act then
            list[#list + 1] = { y = y, act = fr.text, fn = fr.act, gated = fr.gated }
        end
    end
    table.sort(list, function(a, c) return a.y < c.y end)
    return list
end

local function isStop(d)
    return d.color and d.color[1] == K.stop[1] and d.color[2] == K.stop[2] and d.color[3] == K.stop[3]
end

local function texts(list)
    local out = {}
    for i, d in ipairs(list) do out[i] = d.text or d.act or "|gap|" end
    return out
end
local function indexOf(list, pattern, from)
    for i = from or 1, #list do
        local t = list[i].text or list[i].act
        if t and t:find(pattern, 1, true) then return i end
    end
end
local function has(list, pattern) return indexOf(list, pattern) ~= nil end

-------------------------------------------------------------------------------
-- A quest-only, uncollected decor never reads Unlocked to buy or Can get now.
-------------------------------------------------------------------------------
do
    fresh(1001)
    SOURCES[1001] = { { type = "quest", data = { questID = 7, questName = "A Quest" } } }
    HA.QuestSources = { [1001] = { questID = 7, questName = "A Quest" } }
    local list = show(1001)
    assert(not has(list, "Unlocked"), "quest-only decor reads Unlocked to buy")
    assert(not has(list, "Can get now"), "quest-only decor reads Can get now")
    assert(has(list, "Not collected"), "an uncollected quest-only decor has no Not collected line")
    assert(select(1, B.ItemState(1001)) == "notOwned")
    assert(select(1, B.ItemState(1001, 999)) ~= "can", "a vendor that does not exist makes it buyable")
    print("hs538_item: quest-only decor is never buyable ok")
end

-------------------------------------------------------------------------------
-- Collection states: owned, counting and not read.
-------------------------------------------------------------------------------
do
    fresh(1002)
    OWNED[1002] = true
    SOURCES[1002] = { { type = "quest", data = { questID = 8, questName = "Q" } } }
    assert(has(show(1002), "Collected"), "owned decor has no Collected line")
    OWNED[1002] = nil
    phase = "counting"
    D.InvalidateMemos()
    local list = show(1002)
    assert(has(list, "Counting"), "no Counting\226\128\166 while the collection is read")
    assert(not has(list, "Collected") and not has(list, "Not collected"), "counting shows an ownership word")
    phase = "notRead"
    D.InvalidateMemos()
    list = show(1002)
    assert(not has(list, "Counting"), "a collection that was never read says Counting")
    assert(not has(list, "Not collected") and not has(list, "Collected"), "not read shows an ownership word")
    assert(B.ItemState(1002) == nil, "not read returns a state")
    phase = "ready"
    D.InvalidateMemos()
    print("hs538_item: collection states ok")
end

-------------------------------------------------------------------------------
-- R31 order, open sources first, gold labels with white values, Show buttons.
-------------------------------------------------------------------------------
do
    fresh(1003, { quality = 3, categoryIDs = { 1 }, firstAcquisitionBonus = 5, totalNumPlaced = 2, totalNumStored = 1 })
    local near = vendor(12, "Near Vendor", { event = "Midsummer" })
    local far = vendor(13, "Far Vendor", { mapID = 200 })
    local hostile = vendor(14, "Horde Vendor")
    OPPOSITE[14], FACTION_LABEL[14] = true, "Horde"
    OFFER[13] = "locked"
    SOURCES[1003] = {
        { type = "quest", data = { questID = 9, questName = "Some Quest" } },
        vsrc(hostile),
        vsrc(far),
        vsrc(near),
        { type = "profession", data = { recipeName = "Table", profession = "Carpentry", spellID = 55 } },
        { type = "drop", data = { mobName = "Boss", zone = "Dungeon" } },
        { type = "event", data = { event = "Midsummer", vendorName = "Fire Vendor", zone = "Hub" } },
        { type = "shop", data = { name = "Bundle" } },
    }
    HA.QuestSources = { [1003] = { questID = 9, questName = "Some Quest" } }
    HA.ProfessionSources = { [1003] = { spellID = 55 } }
    HA.DropSources = { [1003] = { mobName = "Boss", zone = "Dungeon" } }
    HA.EventSources.EventVendors = { [12] = { event = "Midsummer" } }
    HA.EventSources[1003] = { event = "Midsummer" }
    HA.ShopSources = { [1003] = { name = "Bundle" } }
    REQS[1003] = { { type = "reputation", standing = "Friendly", faction = "Stormwind", met = false } }
    local presentationsBefore = presentations
    local list = show(1003)
    assert(presentations == presentationsBefore, "the page read a presentation for its state")

    local iState = indexOf(list, "Not collected") or indexOf(list, "Can get now")
    local iBonus = indexOf(list, "First-Time Collection Bonus Available")
    local iActive = indexOf(list, "Active now: Midsummer")
    local iReq = indexOf(list, "Requires")
    local iWhere = indexOf(list, "Where to get it")
    local iReport = indexOf(list, "Report a problem")
    assert(iState and iActive and iBonus and iReq and iWhere and iReport, table.concat(texts(list), " | "))
    assert(iState < iActive and iActive < iBonus and iBonus < iReq and iReq < iWhere and iWhere < iReport, "R31 order is wrong")
    assert(list[iReport].gated == true and iReport == #list, "Report is not the last, gated control")
    assert(has(list, "Placed"), "the collection counts are missing from the page")
    local activeLines = 0
    for _, d in ipairs(list) do
        if d.text and d.text:find("Active now: Midsummer", 1, true) then activeLines = activeLines + 1 end
    end
    assert(activeLines == 1, "Active now is shown " .. activeLines .. " times")

    local iNear = indexOf(list, "Near Vendor")
    local iFar = indexOf(list, "Far Vendor")
    local iQuest = indexOf(list, "Some Quest")
    local iHostile = indexOf(list, "Horde Vendor")
    assert(iNear < iFar and iFar < iQuest and iQuest < iHostile, "sources are not open-first: "
        .. table.concat({ iNear, iFar, iQuest, iHostile }, ","))
    assert(list[iNear].text:find("|cffffd100Vendor:|r Near Vendor", 1, true), "vendor label is not gold with a white value")
    local value = list[iNear].text:match("|r (.*)$")
    assert(value == "Near Vendor" and not value:find("|c", 1, true), "the value is not plain white")
    assert(has(list, "Can get now here"), "no Can get now here on the open vendor")
    assert(indexOf(list, "Can get now here") < iFar, "Can get now here is not in the open vendor's block")
    assert(has(list, "Horde only"), "no faction stop line")

    -- Every Show button opens the source's page by type and key; Shop has none.
    local function act(label)
        for _, d in ipairs(list) do
            if d.act == label then return d end
        end
    end
    for label, want in pairs({ ["Show recipe"] = { "professions", 55 }, ["Show drop"] = { "drops", "Boss|Dungeon" },
        ["Show event"] = { "events", "Midsummer" }, ["Show quest"] = { "quests", 9 } }) do
        local d = assert(act(label), label .. " has no button")
        routed = {}
        d.fn()
        assert(#routed == 1 and routed[1].kind == "source" and routed[1].key == want[1] and routed[1].id == want[2]
            and routed[1].seed == nil, label .. " goes to the wrong page")
    end
    local shows, npcs = 0, {}
    routed = {}
    for _, d in ipairs(list) do
        if d.act == "Show vendor" then
            shows = shows + 1
            d.fn()
            npcs[#npcs + 1] = routed[#routed].kind == "vendor" and routed[#routed].id
        end
    end
    assert(shows == 3, "each known vendor needs a Show vendor button, got " .. shows)
    table.sort(npcs)
    assert(table.concat(npcs, ",") == "12,13,14" and #routed == 3, "Show vendor goes to the vendor page by npcID: " .. table.concat(npcs, ","))
    local f = assert(io.open(root .. "/UI/Browser/Item.lua", "rb"))
    local src = f:read("*a")
    f:close()
    assert(not src:find("ShowTab", 1, true), "the item page opens sources through the router, not a tab call")
    local shopAt = indexOf(list, "Shop")
    assert(shopAt and not (list[shopAt + 1] and (list[shopAt + 1].act or ""):find("Show")), "the Shop block has a Show button")
    print("hs538_item: order, open-first, gold labels and Show keys ok")

    -- "A vendor" (no record) has no Show button.
    SOURCES[1003] = { { type = "vendor", data = { npcID = 4040, name = "Ghost" } } }
    list = show(1003)
    for _, d in ipairs(list) do assert(d.act ~= "Show vendor", "an unknown vendor has a Show button") end
    assert(has(list, "Vendor: Ghost"), "an unrecorded vendor lost its name")
    HA.EventSources.EventVendors = {}
end

-------------------------------------------------------------------------------
-- The flag comes from any open event offer, not from the top block.
-------------------------------------------------------------------------------
do
    fresh(1010)
    local plain = vendor(81, "Plain Vendor")
    local event = vendor(82, "Event Vendor", { mapID = 200, event = "Midsummer" })
    HA.EventSources.EventVendors = { [82] = { event = "Midsummer" } }
    SOURCES[1010] = { vsrc(event), vsrc(plain) }
    local list = show(1010)
    assert(indexOf(list, "Plain Vendor") < indexOf(list, "Event Vendor"), "sanity: the plain vendor is the top block")
    assert(indexOf(list, "Active now: Midsummer") < indexOf(list, "Where to get it"),
        "the flag follows the top block, not the open event offer")
    HA.EventSources.EventVendors = {}
    print("hs538_item: active-now flag ok")
end

-------------------------------------------------------------------------------
-- Faction: an item is faction-only only when every source is an other-faction vendor.
-------------------------------------------------------------------------------
do
    fresh(1011)
    local horde = vendor(91, "Horde Seller")
    OPPOSITE[91], FACTION_LABEL[91] = true, "Horde"
    SOURCES[1011] = { { type = "achievement", data = { achievementID = 5, achievementName = "An Achievement" } }, vsrc(horde) }
    HA.AchievementSources = { [1011] = { achievementID = 5, achievementName = "An Achievement" } }
    local list = show(1011)
    local i = assert(indexOf(list, "Not collected"), "achievement plus Horde vendor: " .. table.concat(texts(list), "|"))
    assert(not isStop(list[i]) and B.ItemState(1011) == "notOwned", "a second source still reads faction only")
    -- One rule on every surface: the page's state line, the tooltip's and a row's (hs538_catalog renders the
    -- Catalog row for the same achievement plus other-faction vendor shape).
    local tip = B.Tooltip()
    tip.lines = {}
    B.ShowItemTooltip(Widget("Frame"), 1011)
    assert(tip.lines[2].text == list[i].text, "the tooltip disagrees with the page: " .. tostring(tip.lines[2].text))
    local before = #made
    B.Widgets.BuildRow(CreateFrame("Button", nil, Widget("Button"))):Set({ name = "Item 1011", state = B.ItemState(1011) })
    local words
    for k = before + 1, #made do words = words or made[k].text == list[i].text end
    assert(words, "a row does not draw the page's words")

    fresh(1012)
    SOURCES[1012] = { vsrc(horde), { type = "vendor", data = {} } }
    list = show(1012)
    assert(B.ItemState(1012) == "notOwned" and has(list, "Not collected"), "a vendor with no record reads faction only")
    local plain
    for _, d in ipairs(list) do
        plain = plain or d.text == "A vendor"
        assert(not (d.text or ""):find("Vendor: Unknown", 1, true), "a vendor with no identity reads Vendor: Unknown")
    end
    assert(plain, "a vendor with no identity is not 'A vendor': " .. table.concat(texts(list), "|"))

    fresh(1013)
    SOURCES[1013] = { vsrc(horde) }
    local state, arg = B.ItemState(1013)
    assert(state == "faction" and arg == "Horde", "a sole other-faction vendor is not faction only")
    OPPOSITE[91] = nil
    print("hs538_item: faction rule ok")
end

-------------------------------------------------------------------------------
-- Locked states: the greyed-out fixture lists no unmet requirement, so it never reads a bare Requires.
-- Otherwise the state line and the Requires section describe the same vendor.
-------------------------------------------------------------------------------
do
    fresh(1014)
    OFFER[71] = "locked"
    SOURCES[1014] = { vsrc(vendor(71, "Greyed Vendor")) }
    REQS[1014] = {}
    local list = show(1014)
    assert(has(list, "Not collected") and not has(list, "Requires"), "greyed out: " .. table.concat(texts(list), "|"))
    assert(B.ItemState(1014) == "notOwned" and B.ItemState(1014, 71) == "notOwned", "greyed out reads a state")

    fresh(1015)
    OFFER[61], OFFER[62] = "locked", "locked"
    SOURCES[1015] = { vsrc(vendor(61, "First Vendor")), vsrc(vendor(62, "Second Vendor", { mapID = 200 })) }
    local met = { type = "reputation", standing = "Honored", faction = "Darnassus", met = true }
    local unmet = { type = "reputation", standing = "Revered", faction = "Ironforge", met = false }
    REQS[1015] = function(npcID) return npcID == 61 and { met } or { unmet } end
    list = show(1015)
    local iState = assert(indexOf(list, "Requires: "), "no Requires state: " .. table.concat(texts(list), "|"))
    assert(list[iState].text:find("Ironforge", 1, true), "the state describes the wrong vendor")
    assert(has(list, "Ironforge") and not has(list, "Darnassus"), "the Requires section describes another vendor")
    assert(indexOf(list, "Revered with Ironforge (not yet)"), "Requires lost the unmet line")
    local _, _, at = B.ItemState(1015)
    assert(at == 62, "the vendor is not reported")

    -- A requirement Homestead can't check: the row reads locked, the page draws the padlock and says so.
    fresh(1016)
    OFFER[63] = "locked"
    SOURCES[1016] = { vsrc(vendor(63, "Rite Vendor")) }
    REQS[1016] = { { type = "unknown", text = "Mystery Rite" } }
    local mark = B.Vis.Marker.Set
    B.Vis.Marker.Set = function(tex, glyph, c) tex.glyph = glyph return mark(tex, glyph, c) end
    list = show(1016)
    B.Vis.Marker.Set = mark
    local state, arg = B.ItemState(1016)
    assert(state == "locked" and arg == "Mystery Rite", "the row reads locked")
    local iReq
    for i, d in ipairs(list) do if d.text == "Mystery Rite" then iReq = i end end
    assert(iReq and list[iReq].glyph == "lock", "the unchecked requirement has no padlock: " .. table.concat(texts(list), "|"))
    assert(list[iReq + 1].text == "Can't check this requirement yet", "no reason under the requirement")
    OFFER[61], OFFER[62], OFFER[63], OFFER[71] = nil, nil, nil, nil
    print("hs538_item: locked states ok")
end

-------------------------------------------------------------------------------
-- The sold-line check: a faction tag that resolves to nothing never reaches a
-- format string as nil.
-------------------------------------------------------------------------------
do
    fresh(1004)
    local v = vendor(21, "Odd Vendor")
    OPPOSITE[21], FACTION_LABEL[21] = true, nil
    SOURCES[1004] = { vsrc(v) }
    local list = show(1004)
    for _, d in ipairs(list) do
        assert(not (d.text and d.text:find("nil", 1, true)), "a nil reached the page: " .. tostring(d.text))
    end
    assert(has(list, "Odd Vendor"))
    local state, arg = B.ItemState(1004)
    assert(state ~= "faction" or arg ~= nil, "the state's faction argument is nil")
    OPPOSITE[21] = nil
    print("hs538_item: nil faction tag ok")
end

-------------------------------------------------------------------------------
-- Two locked vendors with different unmet requirements: page and tooltip name the same one, the vendor with
-- the fewest unmet (here the second in source order).
-------------------------------------------------------------------------------
do
    fresh(1020)
    OFFER[101], OFFER[102] = "locked", "locked"
    SOURCES[1020] = { vsrc(vendor(102, "Late Vendor")), vsrc(vendor(101, "Early Vendor", { mapID = 200 })) }
    local a1 = { type = "reputation", standing = "Revered", faction = "Ironforge", met = false }
    local a2 = { type = "reputation", standing = "Honored", faction = "Darnassus", met = false }
    local b1 = { type = "reputation", standing = "Friendly", faction = "Orgrimmar", met = false }
    REQS[1020] = function(npcID) return npcID == 102 and { a1, a2 } or { b1 } end
    local list = show(1020)
    local line = list[assert(indexOf(list, "Requires: "), "no Requires state")].text
    assert(line == "Requires: Friendly with Orgrimmar", "state line: " .. line)
    assert(has(list, "Friendly with Orgrimmar (not yet)") and not has(list, "Ironforge"), "Requires names another vendor")
    local tip = B.Tooltip()
    tip.lines = {}
    B.ShowItemTooltip(Widget("Frame"), 1020)
    assert(tip.lines[2].text == line, "the tooltip names another vendor: " .. tostring(tip.lines[2].text))
    OFFER[101], OFFER[102] = nil, nil

    fresh(1021)
    INFO[1021] = nil
    SOURCES[1021] = { vsrc(vendor(103, "Unknown Owner Vendor")) }
    assert(B.ItemState(1021) == nil and B.ItemState(1021, 103) == nil, "unknown ownership reads a state")
    assert(not has(show(1021), "collected"), "unknown ownership shows an ownership word")
    print("hs538_item: locked order and unknown ownership ok")
end

-------------------------------------------------------------------------------
-- An out-of-season holiday item reads "<Event> only" on every surface.
-------------------------------------------------------------------------------
do
    fresh(1022)
    local v = vendor(111, "Fire Seller", { event = "Midsummer" })
    HA.EventSources.EventVendors = { [111] = { event = "Midsummer" } }
    SOURCES[1022] = { vsrc(v) }
    inSeason = false
    local state, arg = B.ItemState(1022)
    assert(state == "event" and arg == "Midsummer", "item-wide: " .. tostring(state))
    state, arg = B.ItemState(1022, 111)
    assert(state == "event" and arg == "Midsummer", "vendor: " .. tostring(state))
    local page = show(1022)
    local at = indexOf(page, "Midsummer only")
    assert(at and page[at].text == "Midsummer only" and at < indexOf(page, "Where to get it"),
        "the page's state line lost the event state: " .. table.concat(texts(page), "|"))
    local tip = B.Tooltip()
    tip.lines = {}
    B.ShowItemTooltip(Widget("Frame"), 1022, 111)
    assert(tip.lines[2] and tip.lines[2].text == "Midsummer only", "tooltip: " .. tostring(tip.lines[2] and tip.lines[2].text))
    fresh(1023)
    SOURCES[1023] = { vsrc(vendor(121, "Fire Seller Two", { event = "Midsummer" })),
        vsrc(vendor(122, "Snow Seller", { event = "Winter Veil" })) }
    HA.EventSources.EventVendors = { [121] = { event = "Midsummer" }, [122] = { event = "Winter Veil" } }
    local _, first = B.ItemState(1023, 121)
    local _, second = B.ItemState(1023, 122)
    assert(first == "Midsummer" and second == "Winter Veil", "a vendor shows another vendor's event")
    inSeason = true
    HA.EventSources.EventVendors = {}
    print("hs538_item: event state ok")
end

-------------------------------------------------------------------------------
-- Combat: Report is off, says why, and does nothing.
-------------------------------------------------------------------------------
do
    fresh(1005)
    local v = vendor(31, "Report Vendor")
    SOURCES[1005] = { vsrc(v) }
    show(1005)
    local function button(label)
        for _, f in ipairs(frames) do
            if f.kind == "Button" and f.act and f.text == label and f.shown then return f end
        end
    end
    local report = assert(button("Report a problem"), "no Report button")
    assert(report.enabled == true, "Report is off out of combat")
    report.scripts.OnClick(report)
    assert(#reports == 1 and reports[1].text:find("Vendor 31: Report Vendor", 1, true), "Report did not gather the vendor")
    assert(reports[1].text:find("Item: Item 1005 (1005)", 1, true))
    Item.SetCombat(true)
    assert(report.enabled == false, "Report stays on in combat")
    Enter(report)
    assert(B.Tooltip().text == "Not available in combat", "no reason on the disabled Report")
    Item.Clear()
    assert(not B.Tooltip():IsShown(), "Clear left the page's own tooltip up")
    Item.Show(1005)
    B.Tooltip():SetOwner(Widget("Frame"))
    B.Tooltip():Show()
    Item.Clear()
    assert(B.Tooltip():IsShown(), "Clear hid a tooltip the page does not own")
    B.Tooltip():Hide()
    Item.Show(1005)
    inCombat = true
    report.scripts.OnClick(report)
    assert(#reports == 1, "Report opened a window in combat")
    inCombat = false
    local wp = button("Set waypoint")
    assert(wp and wp.enabled, "Set waypoint must stay on in combat")
    Item.SetCombat(false)
    assert(report.enabled == true, "Report stays off after combat")
    B.State.inCombat = true
    Item.Show(1005)
    assert(report.enabled == false, "a redraw in combat enables Report")
    B.State.inCombat = false
    Item.SetCombat(false)
    wp.scripts.OnClick(wp)
    assert(#waypoints == 1 and waypoints[1][1] == 100, "Set waypoint did not set")
    print("hs538_item: combat gate ok")
end

-------------------------------------------------------------------------------
-- A redraw never walks and never grows the pools.
-------------------------------------------------------------------------------
do
    fresh(1006)
    SOURCES[1006] = { vsrc(vendor(41, "Pool Vendor")) }
    show(1006)
    local before, count = walks, #frames
    for _ = 1, 3 do Item.Show(1006) end
    assert(walks == before, "Show walked the catalog")
    assert(#frames == count, "Show built new frames on a redraw")
    Item.Clear()
    Item.Show(1006)
    assert(walks == before and #frames == count, "Clear then Show walked or rebuilt")
    print("hs538_item: no walk, no rebuild ok")
end

-------------------------------------------------------------------------------
-- No red outside the faction state, on the page or in the tooltip.
-------------------------------------------------------------------------------
do
    fresh(1007)
    local v = vendor(51, "Locked Vendor")
    OFFER[51] = "gated"
    local h = vendor(52, "Other Side")
    OPPOSITE[52], FACTION_LABEL[52] = true, "Horde"
    SOURCES[1007] = { vsrc(v), vsrc(h) }
    REQS[1007] = { { type = "reputation", standing = "Friendly", faction = "Stormwind", met = false },
        { type = "level", level = 10, met = true } }
    local list = show(1007)
    local red = 0
    for _, d in ipairs(list) do
        if isStop(d) then
            red = red + 1
            assert(d.text:find("only", 1, true), "red outside the faction state: " .. d.text)
        end
    end
    assert(red == 1, "expected exactly the faction line to be red, got " .. red)
    assert(has(list, "(not yet)") and has(list, "(done)"), "requirement lines lost their words")

    local tip = B.Tooltip()
    local function lines()
        tip.lines = {}
        B.ShowItemTooltip(Widget("Frame"), 1007, 51)
        return tip.lines
    end
    local presBefore = presentations
    local ls = lines()
    assert(presentations == presBefore, "the tooltip read a presentation")
    local state = ls[2]
    assert(state and state.text == "Requires: Friendly with Stormwind", "tooltip state: " .. tostring(state and state.text))
    for _, l in ipairs(ls) do
        assert(not (l.r == K.stop[1] and l.g == K.stop[2]), "red line in the tooltip: " .. l.text)
    end
    OFFER[51] = nil
    ls = lines()
    assert(ls[2].text == "Can get now" and ls[2].g == K.can[2], "tooltip lost Can get now for an open vendor")

    -- A nil colour override (the quality is not coloured yet) draws white and does not error.
    qualityColor = nil
    ls = lines()
    assert(ls[1].r == 1 and ls[1].g == 1 and ls[1].b == 1, "a missing quality colour is not white")
    qualityColor = { r = 0, g = 0.5, b = 1 }

    -- A quest-only decor in the tooltip.
    fresh(1008)
    SOURCES[1008] = { { type = "quest", data = { questID = 3, questName = "Q" } } }
    ls = lines and (function() tip.lines = {} B.ShowItemTooltip(Widget("Frame"), 1008) return tip.lines end)()
    for _, l in ipairs(ls) do
        assert(not l.text:find("Unlocked", 1, true) and l.text ~= "Can get now", "tooltip says buyable: " .. l.text)
    end
    assert(ls[2].text == "Not collected")
    print("hs538_item: no red outside the faction state ok")
end

-------------------------------------------------------------------------------
-- Source text: the retired state words and colours are gone for good.
-------------------------------------------------------------------------------
do
    assert(S.stateLabel == nil and K.stateText == nil, "the old state table survives")
    for _, file in ipairs({ "Item", "Browser", "Style" }) do
        local f = assert(io.open(root .. "/UI/Browser/" .. file .. ".lua", "rb"))
        local src = f:read("*a")
        f:close()
        assert(not src:find("Unlocked", 1, true) and not src:find("stateLabel", 1, true)
            and not src:find("stateText", 1, true), file .. " still names the old buy state")
    end
    local f = assert(io.open(root .. "/UI/Browser/Item.lua", "rb"))
    local src = f:read("*a")
    f:close()
    local _, stops = src:gsub("K%.stop", "")
    assert(stops == 1, "red appears " .. stops .. " times in the item page")
    assert(not src:find("GetItemPresentation", 1, true) and not src:find("ItemStatus", 1, true),
        "the page reads a presentation for its state")
    print("hs538_item: retired state words gone ok")
end

-- The page's kind is the Catalog nav's, whether categoryIDs is an array or a set.
do
    for id, ids in pairs({ [1031] = { 2 }, [1032] = { [2] = true } }) do
        fresh(id, { quality = 3, categoryIDs = ids, totalNumPlaced = 0, totalNumStored = 0 })
        local before = #made
        show(id)
        local meta
        for k = before + 1, #made do
            local t = made[k].text
            meta = meta or type(t) == "string" and t:find(" %- Structural$") and t
        end
        assert(meta, "item " .. id .. " does not read Structural")
        assert(S.KindOf(INFO[id]) == 2, "the Catalog nav files item " .. id .. " elsewhere")
    end
    print("hs538_item: decor kind ok")
end

-- A vendor no scan has confirmed: the page and the tooltip say so in full.
do
    fresh(1033)
    SOURCES[1033] = { vsrc(vendor(65, "Unscanned Vendor")) }
    local list = show(1033)
    local sentence = B.Facts.NotConfirmed()
    assert(sentence:find("No scan has confirmed", 1, true), sentence)
    assert(has(list, sentence), "the page lacks the full sentence: " .. table.concat(texts(list), "|"))
    assert(D.TooltipData(1033).unconfirmed, "the tooltip data misses the unconfirmed vendor")
    local tip = B.Tooltip()
    tip.lines = {}
    B.ShowItemTooltip(Widget("Frame"), 1033)
    local said
    for _, l in ipairs(tip.lines) do said = said or l.text == sentence end
    assert(said, "the tooltip does not say the vendor is not confirmed")
    print("hs538_item: not confirmed ok")
end

-- The confirmation date is the newer of the shipped one and the player's own scan. (The vendor page no longer
-- draws it; the item page does.)
do
    rawset(_G, "date", rawget(_G, "date") or os.date)
    fresh(1034)
    local v = vendor(66, "Scanned Vendor", { scanConfirmed = "2026-10-01" })
    SOURCES[1034] = { vsrc(v) }
    assert(has(show(1034), "Confirmed by a scan on 2026-10-01"), "the shipped date shows")
    RECORDS[66] = { lastScanned = os.time({ year = 2026, month = 9, day = 1, hour = 12 }) }
    D.InvalidateMemos()
    assert(has(show(1034), "Confirmed by a scan on 2026-10-01"), "an older scan does not replace the shipped date")
    RECORDS[66] = { lastScanned = os.time({ year = 2026, month = 10, day = 20, hour = 12 }) }
    D.InvalidateMemos()
    assert(has(show(1034), "Confirmed by a scan on 2026-10-20"), "the newer of the two shows")
    RECORDS[66] = nil
    print("hs538_item: confirmation date ok")
end

-- A linked id with no decor record and no sources (Catalog lands on it with no row) still draws a page.
do
    D.InvalidateMemos()
    local list = show(5555)
    assert(#list > 0, "an id with no record draws no page")
    local state = B.ItemState(5555)
    assert(state == nil or state == "notOwned", "an id with no record reads " .. tostring(state))
    print("hs538_item: id with no record ok")
end

-- The link tooltip: the game's own tooltip for a hyperlink on the browser's dedicated frame. A link the game
-- cannot describe, or none, leaves no empty box.
do
    local realTooltip = B.Tooltip
    local lines, hyperlinks, owners, visible = 0, {}, {}, false
    local tip = {
        SetOwner = function(_, owner, anchor)
            owners[#owners + 1] = { owner, anchor }
            lines, visible = 0, false
        end,
        SetHyperlink = function(_, link)
            hyperlinks[#hyperlinks + 1] = link
            lines = link == "achievement:9001" and 3 or 0
        end,
        NumLines = function() return lines end,
        Show = function() visible = true end,
        Hide = function() visible = false end,
    }
    B.Tooltip = function() return tip end
    local owner = {}
    B.ShowLinkTooltip(owner, "achievement:9001")
    assert(hyperlinks[1] == "achievement:9001" and owners[1][1] == owner and owners[1][2] == "ANCHOR_RIGHT" and visible,
        "the tooltip is set from the link on the row")
    B.ShowLinkTooltip(owner, "quest:7")
    assert(hyperlinks[2] == "quest:7" and not visible, "a link the game cannot describe leaves no empty tooltip")
    visible = true
    B.ShowLinkTooltip(owner, nil)
    assert(#hyperlinks == 2 and not visible, "no link sets nothing and hides the tooltip")
    B.Tooltip = realTooltip
    print("hs538_item: link tooltip ok")
end

print("hs538_item: ok")
