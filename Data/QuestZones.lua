-- The zone of each decor quest that has no start or dig-site row, keyed by quest ID. Generated: do not hand-edit.
-- mapID is a zone only, with no position, so it is never used for a waypoint or pin. turnIn is the continent
-- map of the quest's turn-in, for a quest whose own map has no continent above it. Built from the game's
-- quest marker tables, falling back to the one zone the catalog's source text names.
local _, HA = ...

HA.QuestZones = {
    [543] = {mapID = 84},
    [12227] = {mapID = 116},
    [30526] = {mapID = 376},
    [35176] = {mapID = 582},
    [36614] = {mapID = 590},
    [36615] = {mapID = 582},
    [36685] = {mapID = 582},
    [38197] = {mapID = 582},
    [38201] = {mapID = 582},
    [42751] = {mapID = 641},
    [48554] = {mapID = 864},
    [49767] = {mapID = 862},
    [52978] = {turnIn = 875},
    [67047] = {mapID = 2024},
    [67063] = {mapID = 2022},
    [70745] = {mapID = 2025},
    [71097] = {mapID = 2024},
    [74332] = {mapID = 2118},
    [78864] = {mapID = 2239},
    [84912] = {expansion = "The War Within", mapID = 1565},
    [90867] = {mapID = 2424},
    [92572] = {expansion = "Midnight", mapID = 2339},
    [92577] = {expansion = "Midnight", mapID = 2339},
    [92578] = {expansion = "Midnight", mapID = 2339},
    [92580] = {expansion = "Midnight", mapID = 2339},
    [92581] = {expansion = "Midnight", mapID = 2339},
    [96507] = {mapID = 2413},
}
