# Homestead Data Pipeline Skill

> **Installation**: Place this folder at `~/.claude/skills/homestead-data/`  
> Or for project-specific: `Homestead/.claude/skills/homestead-data/`

---

## When to Use

Use this skill when:
- Adding/modifying vendor database entries
- Working with NPC ID corrections
- Transforming Wowhead data to Lua
- Debugging ownership detection
- Adding new data sources (achievements, quests)

---

## Vendor Database Format

Location: `Data/VendorDatabase.lua`

```lua
{
    npcID = 219318,              -- REQUIRED: Verified in-game
    name = "Jorid",              -- REQUIRED: Exact match
    mapID = 2339,                -- REQUIRED: For map pins
    zone = "Dornogal",           -- Display name
    coords = {x = 0.45, y = 0.52}, -- Normalized 0-1
    faction = "Neutral",         -- Alliance/Horde/Neutral
    notes = "Requires Renown 5", -- Optional
}
```

---

## Critical: Coordinate Format

**ALWAYS use normalized 0-1 coordinates, NOT 0-100 percentage.**

```lua
-- CORRECT
coords = {x = 0.45, y = 0.52}

-- WRONG (will break map pins)
coords = {x = 45, y = 52}

-- Converting from Wowhead:
local x = wowheadX / 100
local y = wowheadY / 100
```

---

## NPC ID Verification

**Wowhead NPC IDs are frequently wrong.** Always verify in-game:

```lua
-- Target vendor, then run:
/run print(UnitGUID("target"))
-- Output: Creature-0-XXXX-XXXX-XXXX-219318-XXXXXXXX
--                                    ^^^^^^ This is the NPC ID
```

---

## Ownership Cache

Location: `db.global.ownedDecor`

```lua
ownedDecor[itemID] = {
    name = "Item Name",
    firstSeen = timestamp,
    lastSeen = timestamp,
}
```

### Check Priority
1. Cache (most reliable)
2. Player bags (newly purchased)
3. API (unreliable after /reload)

---

## Adding Achievement Data

File: `Data/AchievementDecor.lua`

```lua
HA.AchievementDecor = {
    [achievementID] = {
        name = "Achievement Name",
        items = {
            {itemID = 123456, name = "Reward Item"},
        },
    },
}
```

---

## Adding Quest Data

File: `Data/QuestDecor.lua`

```lua
HA.QuestDecor = {
    [questID] = {
        name = "Quest Name",
        itemID = 123456,
        mapID = 2339,
        faction = "Neutral",
    },
}
```

---

## Map ID Lookup

```lua
-- Get current zone
/run print(C_Map.GetBestMapForUnit("player"))

-- Get zone info
/run local m=C_Map.GetBestMapForUnit("player") local i=C_Map.GetMapInfo(m) print(m, i.name)
```

### Key Continent IDs
| Continent | ID |
|-----------|-----|
| Khaz Algar | 2274 |
| Dragon Isles | 1978 |
| Shadowlands | 1550 |

---

## Data Quality Checklist

Before adding a vendor:
- [ ] NPC ID verified in-game
- [ ] Coordinates normalized 0-1
- [ ] Faction is correct
- [ ] Zone mapID matches location

---

## Debugging

```lua
-- Check if item is cached
/run print(HomesteadDB.global.ownedDecor[ITEMID] and "Cached" or "Not cached")

-- Check scanned vendors
/run for id,v in pairs(HomesteadDB.global.scannedVendors) do print(id, v.name) end

-- Check NPC corrections
/hs corrections
```
