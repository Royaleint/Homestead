-- luacheck: globals assert loadfile print error

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- The "browser" presentation context is cache-only. The real SourceManager runs
-- with a CatalogStore whose IsOwnedFresh raises; reading a presentation in the
-- browser context, with and without a vendor, must never reach it.
-------------------------------------------------------------------------------

local freshProbeCalls = 0

local HA = {
    Constants = { Icons = {}, SourceBadgeAtlas = {}, Colors = {} },
    Addon = { db = { profile = {}, global = { parsedSources = {} } }, RegisterModule = function() end },
    CatalogStore = {
        IsOwned = function(_, itemID) return itemID == 2001 end,
        IsOwnedFresh = function()
            freshProbeCalls = freshProbeCalls + 1
            error("the browser context must not make a fresh ownership probe")
        end,
        IsOwnershipUnknowable = function() return false end,
        GetRequirements = function() return nil end,
    },
}

assert(loadfile(root .. "/Data/SourceManager.lua"))("Homestead", HA)
local SM = HA.SourceManager

local owned = SM:GetItemPresentation(2001, { context = "browser", npcID = 999, isVendorContext = true })
assert(owned.isOwned == true and owned.availabilityState == "owned")

local unownedVendor = SM:GetItemPresentation(2002, { context = "browser", npcID = 999, isVendorContext = true })
assert(unownedVendor.isOwned == false)

local ownedPlain = SM:GetItemPresentation(2001, { context = "browser" })
assert(ownedPlain.isOwned == true)

local unownedPlain = SM:GetItemPresentation(2002, { context = "browser" })
assert(unownedPlain.isOwned == false)

assert(freshProbeCalls == 0, "browser presentation reads made " .. freshProbeCalls .. " fresh probe(s)")

-- Control: the same call in an uncached context does reach the fresh probe.
assert(not pcall(SM.GetItemPresentation, SM, 2002, { context = "standard" }),
    "control: a standard-context read must reach the fresh probe")
assert(freshProbeCalls > 0)

print("hs534_browser_context: ok")
