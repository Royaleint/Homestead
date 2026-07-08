--[[
    Homestead - VendorStagedAdditions
    Reviewed-but-unverified vendor data staged by the evidence pipeline
    (HS-147 Phase D). PIPELINE-OWNED: rows are appended by promotion
    passes and removed when a live scan graduates them into the generated
    tables - do not hand-edit, and do not fold into VendorOffers.lua or
    VendorIdentity.lua (both are regenerated and would drop these tables).

    Loads after VendorIdentity.lua and VendorOffers.lua (see TOC); the
    tables attach to those modules and the identity indexes are rebuilt
    so staged vendors appear on map pins. Every row carries
    unverified = true until in-game verification (Gate 2 / live scan).

    First promotion: HS-153, 2026-07-07 (77 offers, 1 vendor identity).
]]

local _, HA = ...

HA.VendorOffers.StagedAdditions = {
  [62088] = {
    [271971] = { price = 20000000, currencies = {}, isUsable = true, unverified = true },
  },
  [112338] = {
    [267372] = { price = 0, currencies = {{id = 1220, amount = 1000}}, isUsable = true, unverified = true },
  },
  [240407] = {
    [263039] = { price = 0, currencies = {{id = 3316, amount = 250}}, isUsable = true, unverified = true },
    [263194] = { price = 0, currencies = {{id = 3316, amount = 250}}, isUsable = true, unverified = true },
    [263195] = { price = 0, currencies = {{id = 3316, amount = 250}}, isUsable = true, unverified = true },
  },
  [250982] = {
    [245284] = { price = 0, currencies = {{id = 2815, amount = 3000}}, isUsable = true, unverified = true },
    [245330] = { price = 0, currencies = {{id = 2815, amount = 3000}}, isUsable = true, unverified = true },
    [251997] = { price = 0, currencies = {{id = 2815, amount = 5000}}, isUsable = true, unverified = true },
  },
  [252873] = {
    [269316] = { price = 0, currencies = {}, isUsable = true, unverified = true },
  },
  [255278] = {
    [250691] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [250692] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [254395] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [254396] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [254397] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [254398] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [254399] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [254678] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [255706] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [255707] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [256329] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [258664] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [258665] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [259464] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [259465] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [259466] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [259467] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [259468] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [259469] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [259470] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [265924] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [265925] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [265926] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [267088] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
  },
  [255297] = {
    [251011] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [251012] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [252008] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [253019] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [255709] = { price = 1250000, currencies = {}, isUsable = true, unverified = true },
    [258300] = { price = 1250000, currencies = {}, isUsable = true, unverified = true },
    [258307] = { price = 1250000, currencies = {}, isUsable = true, unverified = true },
    [258663] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [260486] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [260487] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [260488] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [263031] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [263032] = { price = 1500000, currencies = {}, isUsable = true, unverified = true },
    [263581] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [263582] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [263583] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [263584] = { price = 1500000, currencies = {}, isUsable = true, unverified = true },
    [267083] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [267616] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [268026] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [268027] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [268028] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
  },
  [255298] = {
    [264352] = { price = 1250000, currencies = {}, isUsable = true, unverified = true },
    [264353] = { price = 1250000, currencies = {}, isUsable = true, unverified = true },
    [265653] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [265654] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [267075] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
  },
  [255299] = {
    [267202] = { price = 1250000, currencies = {}, isUsable = true, unverified = true },
  },
  [255319] = {
    [245298] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [245299] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [245300] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
  },
  [255325] = {
    [246934] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [246935] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [250092] = { price = 100000, currencies = {}, isUsable = true, unverified = true },
    [252037] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [252038] = { price = 750000, currencies = {}, isUsable = true, unverified = true },
    [258570] = { price = 1000000, currencies = {}, isUsable = true, unverified = true },
    [262962] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [266233] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [266249] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [266250] = { price = 250000, currencies = {}, isUsable = true, unverified = true },
    [268029] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [268030] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
    [272359] = { price = 500000, currencies = {}, isUsable = true, unverified = true },
  },
}

HA.VendorIdentity.StagedAdditions = {
    [250982] = {
        name = "Dethelin",
        mapID = 2393,
        x = 0.5247, y = 0.4730,
        zone = "Silvermoon City",
        subzone = "Murder Row",
        faction = "Neutral",
        currency = "Resonance Crystals",
        expansion = "Midnight",
        unverified = true,
    },
}

-- Staged identities join the map/expansion indexes built at VendorIdentity load.
HA.VendorIdentity:BuildIndexes()
