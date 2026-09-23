--[[
    Homestead - RoomMapping
    Hand-curated (HS-451). Total entries: 17

    Static roomRecordID -> itemID mapping for room plans
    (Enum.HousingCatalogEntryType.Room = 2). Seeds CatalogStore's room index
    (BuildRoomIndex) so a plan's ownership resolves through
    C_HousingCatalog.GetCatalogEntryInfoByRecordID(2, roomRecordID).
    Room catalog entries carry no itemID, so this table is the only link from
    a plan item to its room. Seven pairs were confirmed in-game against the
    room's catalog name; the other ten come from each plan item's room-grant
    data and have not yet been seen in-game. Scope: "Fen" Rucket stock at
    npcIDs 257295 and 257297; other plans vendors are separate work.
--]]

local _, HA = ...

HA.RoomMapping = {
    -- "Fen" Rucket, npcID 257295
    [273] = 272997,  -- Stormwind Armory
    [282] = 274665,  -- Stormwind Grand Hall
    [281] = 274666,  -- Stormwind Display Room
    [277] = 274667,  -- Stormwind Kitchen
    [288] = 274668,  -- Bel'ameth Meeting Room
    [289] = 274669,  -- Bel'ameth Theater
    [287] = 274670,  -- Bel'ameth Temple Room
    [290] = 274671,  -- Bel'ameth Nestled Bedroom
    [400] = 276243,  -- Autumnal Westfall Barn Room
    [401] = 276244,  -- Springtime Westfall Barn Room
    -- "Fen" Rucket, npcID 257297
    [286] = 274661,  -- Silvermoon Display Room
    [307] = 274662,  -- Silvermoon Small Study
    [285] = 274664,  -- Silvermoon Lofty Study
    [132] = 274673,  -- Orgrimmar Council Room
    [292] = 274674,  -- Orgrimmar Theater
    [151] = 274675,  -- Orgrimmar Stone Pit Room
    [294] = 274676,  -- Orgrimmar Display Room
}
