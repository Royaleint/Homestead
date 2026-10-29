-- luacheck: globals assert loadfile print rawset io UnitFactionGroup

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser source keys: Facts.SourceKey is the only builder of Sources
-- row keys and "Show" link keys. Each type keys as documented, "A vendor" and
-- an unknown vendor key to nil, and every shipped entry of the keyed data
-- files yields a key.
-------------------------------------------------------------------------------

local vendors = { [100] = { npcID = 100 } }
local HA = {
    DecorBrowser = {}, L = { Alliance = "Alliance", Horde = "Horde", ["%s or the %s"] = "%s or the %s" },
    VendorData = { GetVendor = function(_, npcID) return vendors[npcID] end },
}
assert(loadfile(root .. "/UI/Browser/Facts.lua"))("Homestead", HA)
local F = HA.DecorBrowser.Facts
local key = F.SourceKey

-- The other faction, the one helper every surface names it with. A Neutral character can use neither,
-- so it is told only the factions its hidden or missing items are sold to.
-- Every character is told only the factions in seen, whatever its own.
for _, mine in ipairs({ "Alliance", "Horde", "Neutral" }) do
    rawset(_G, "UnitFactionGroup", function() return mine end)
    assert(F.OtherFaction() == nil and F.OtherFaction({ [""] = 2 }) == nil, mine .. " is told a faction with none seen")
    assert(F.OtherFaction({ Alliance = 1 }) == "Alliance" and F.OtherFaction({ Horde = 2 }) == "Horde",
        mine .. " is told a faction its items are not limited to")
end
assert(F.OtherFaction({ Horde = 1, Alliance = 3 }) == "Alliance or the Horde", "both factions seen")
local p = F.FactionParts({ Horde = 1, Alliance = 3, [""] = 1 })
assert(#p == 2 and p[1][1] == 3 and p[1][2] == "Alliance" and p[2][1] == 1 and p[2][2] == "Horde", "two footer parts")
assert(#F.FactionParts({}) == 0, "no faction part with none seen")
for _, file in ipairs({ "Summary", "Catalog", "Sources" }) do
    local f = assert(io.open(root .. "/UI/Browser/" .. file .. ".lua", "rb"))
    local src = f:read("*a")
    f:close()
    assert(not src:find("UnitFactionGroup", 1, true), file .. " names the other faction itself")
end

assert(key("vendors", { npcID = 100 }, 1) == 100)
assert(key("vendors", { name = "A vendor" }, 1) == nil, '"A vendor" has no key')
assert(key("vendors", { npcID = 404 }, 1) == nil, "an npcID with no vendor record has no key")
assert(key("achievements", { achievementID = 7, achievementName = "A" }, 1) == 7)
assert(key("quests", { questID = 8, questName = "Q" }, 1) == 8)
assert(key("professions", { profession = "Tailoring", recipeName = "R", spellID = 9 }, 1) == 9)
assert(key("drops", { mobName = "Rare", zone = "Zone" }, 1) == "Rare|Zone")
assert(key("drops", { mobName = "Rare" }, 1) == nil, "a drop without a zone has no key")
assert(key("events", { event = "Hallow's End", vendorName = "V" }, 1) == "Hallow's End")
assert(key("shop", { name = "Bundle" }, 55) == 55, "Shop rows key by item")
assert(key("vendors", nil, 1) == nil and key("nonsense", { npcID = 100 }, 1) == nil)

local want = {
    vendor = "vendors", achievement = "achievements", quest = "quests", profession = "professions",
    drop = "drops", event = "events", shop = "shop",
}
local n = 0
for dataType, sourcesType in pairs(F.SOURCE_TYPE) do
    assert(want[dataType] == sourcesType, dataType .. " maps to " .. tostring(sourcesType))
    n = n + 1
end
assert(n == 7)

-- Every shipped entry keys.
local data = {}
for _, file in ipairs({ "ProfessionSources", "DropSources", "QuestSources", "AchievementSources" }) do
    assert(loadfile(root .. "/Data/" .. file .. ".lua"))("Homestead", data)
end
for sourcesType, tbl in pairs({ professions = data.ProfessionSources, drops = data.DropSources,
    quests = data.QuestSources, achievements = data.AchievementSources }) do
    local count = 0
    for itemID, entry in pairs(tbl) do
        if type(itemID) == "number" then
            count = count + 1
            assert(key(sourcesType, entry, itemID) ~= nil, sourcesType .. " entry " .. itemID .. " has no key")
        end
    end
    assert(count > 0, sourcesType .. " loaded no entries")
end

print("hs538_source_keys: ok")
