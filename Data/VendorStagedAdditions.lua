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
    unverified = true until in-game verification (live scan).

    First promotion: HS-153, 2026-07-07 (77 offers, 1 vendor identity).
]]
-- Graduated 2026-07-08: 0 offer(s) graduated, 3 culled (see human-review-ledger.json).
-- Graduated 2026-07-08: 74 offer(s) graduated, 0 culled (see human-review-ledger.json).

local _, HA = ...

HA.VendorOffers.StagedAdditions = {
}

HA.VendorIdentity.StagedAdditions = {
}

-- Staged identities join the map/expansion indexes built at VendorIdentity load.
HA.VendorIdentity:BuildIndexes()
