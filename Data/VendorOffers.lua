--[[
    Homestead - VendorOffers
    Per-vendor offer data: price, currencies, merchantSlot flags.

    GENERATED table: do not hand-edit. Regenerate:
        python Home_Dev/scripts/generate_vendor_offers.py
    MANUAL table: safe to edit. Same schema as GeneratedBase. Values here win over GeneratedBase.
    TOMBSTONES: bare itemID or "npcID:itemID" string key to suppress from all offer output.

    Schema per entry:
        [npcID] = {
            [itemID] = {
                price            = <copper>,  -- gold cost in copper; 0 if free or currency-only
                currencies       = { {id=<currencyID>, amount=<n>}, ... },
                itemCosts        = { {itemID=<n>, amount=<n>}, ... },   -- i-prefix costs; omitted when empty
                namedCosts       = { {name=<str>, amount=<n>}, ... },   -- n-prefix costs; omitted when empty
                isUsable         = <bool>,
                isPurchasable    = <bool>,
                merchantSlot     = <n>,
                hasExtendedCost  = <bool>,
            },
            ...
        }
]]

local _, HA = ...

-- GENERATED: do not hand-edit. Regenerate: python Home_Dev/scripts/generate_vendor_offers.py
-- [npcID] = { [itemID] = { price, currencies[, itemCosts][, namedCosts], isUsable[, isPurchasable][, merchantSlot][, hasExtendedCost] } }
local GeneratedBase = {}

-- MANUAL: safe to edit. Same schema as GeneratedBase. Values here win over GeneratedBase.
local ManualOverrides = {}

-- TOMBSTONES: bare itemID or "npcID:itemID" string key to suppress from all offer output.
local Tombstones = {}

HA.VendorOffers = {
    GeneratedBase   = GeneratedBase,
    ManualOverrides = ManualOverrides,
    Tombstones      = Tombstones,
}
