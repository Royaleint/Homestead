--[[
    Homestead - ProfessionTrainerLocations
    Hand-curated trainer locations for profession-sourced decor map pins (HS-079).

    Shape: flat array of trainer records. Each record:
        { profession, skillTier, mapID, x, y, faction? }
      - profession: e.g. "Tailoring" (must match HA.ProfessionSources.profession).
      - skillTier:  e.g. "Khaz Algar Tailoring" (must match HA.ProfessionSources.skillTier).
      - mapID:      zone-level uiMapID (NOT subzone — see HS-079 Decision D).
      - x, y:       0-1 normalized coords on that map.
      - faction:    optional "Alliance" | "Horde". Omit for faction-neutral hubs.

    Multi-location handled by separate records (matches Vendor pattern — Stormwind
    Innkeeper and Ironforge Innkeeper are distinct entries in VendorDatabase).
    Faction split handled by separate records with a `faction` field.

    v1 coverage: current-expansion tiers (Khaz Algar + Midnight) for all
    professions present in HA.ProfessionSources. Older expansion tiers are
    deferred to a follow-up ticket; items whose skillTier is not in this table
    are silently skipped by the collector (no error, no pin).

    Regeneration: hand-edited. No generator script. Verify with /way in-game.
--]]

local _, HA = ...

HA.ProfessionTrainerLocations = {
    -- ---- Khaz Algar — Dornogal (Isle of Dorn, mapID 2248) ----
    { profession = "Tailoring",      skillTier = "Khaz Algar Tailoring",      mapID = 2248, x = 0.475, y = 0.485 },  -- TBC /way
    { profession = "Blacksmithing",  skillTier = "Khaz Algar Blacksmithing",  mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Leatherworking", skillTier = "Khaz Algar Leatherworking", mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Engineering",    skillTier = "Khaz Algar Engineering",    mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Alchemy",        skillTier = "Khaz Algar Alchemy",        mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Inscription",    skillTier = "Khaz Algar Inscription",    mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Jewelcrafting", skillTier = "Khaz Algar Jewelcrafting",  mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Enchanting",     skillTier = "Khaz Algar Enchanting",     mapID = 2248, x = 0.475, y = 0.485 },
    { profession = "Cooking",        skillTier = "Khaz Algar Cooking",        mapID = 2248, x = 0.475, y = 0.485 },

    -- ---- Midnight — The Den (Harandar, mapID 2413) ----
    { profession = "Tailoring",      skillTier = "Midnight Tailoring",        mapID = 2413, x = 0.495, y = 0.490 },  -- TBC /way
    { profession = "Blacksmithing",  skillTier = "Midnight Blacksmithing",    mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Leatherworking", skillTier = "Midnight Leatherworking",   mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Engineering",    skillTier = "Midnight Engineering",      mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Alchemy",        skillTier = "Midnight Alchemy",          mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Inscription",    skillTier = "Midnight Inscription",      mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Jewelcrafting", skillTier = "Midnight Jewelcrafting",    mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Enchanting",     skillTier = "Midnight Enchanting",       mapID = 2413, x = 0.495, y = 0.490 },
    { profession = "Cooking",        skillTier = "Midnight Cooking",          mapID = 2413, x = 0.495, y = 0.490 },
}

-- ByMapID index built inline at file load.
-- Mirrors Data/EventSources.lua:78-88's EventVendorsByMapID pattern.
HA.ProfessionTrainerLocations.ByMapID = {}
for _, entry in ipairs(HA.ProfessionTrainerLocations) do
    local mapID = entry.mapID
    if mapID then
        if not HA.ProfessionTrainerLocations.ByMapID[mapID] then
            HA.ProfessionTrainerLocations.ByMapID[mapID] = {}
        end
        table.insert(HA.ProfessionTrainerLocations.ByMapID[mapID], entry)
    end
end
