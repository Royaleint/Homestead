-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Decor Browser source keys: Facts.SourceKey is the only builder of Sources
-- row keys and "Show" link keys. Each type keys as documented, "A vendor" and
-- an unknown vendor key to nil, and every shipped entry of the keyed data
-- files yields a key.
-------------------------------------------------------------------------------

local vendors = { [100] = { npcID = 100 } }
local HA = {
    DecorBrowser = {},
    VendorData = { GetVendor = function(_, npcID) return vendors[npcID] end },
}
assert(loadfile(root .. "/UI/Browser/Facts.lua"))("Homestead", HA)
local F = HA.DecorBrowser.Facts
local key = F.SourceKey

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
