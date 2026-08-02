-- luacheck: globals assert loadfile print GetBuildInfo

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- HS-245: vendors flagged `unreleased` are revealed ONLY on a dev build of a
-- client that has already shipped the content. Both conditions must fail
-- closed, because the failure that matters is a packaged release drawing map
-- pins for content that does not exist.
--
-- VendorFilter reads the client build once at load time, so each case loads the
-- module fresh against its own GetBuildInfo stub.
-------------------------------------------------------------------------------

local RETAIL_INTERFACE = 120007  -- 12.0.7
local PTR_INTERFACE = 120100     -- 12.1, the build the flagged rows target

-- Load VendorFilter with a given client build and dev-build flag, and hand back
-- the filter plus the namespace it was loaded into.
local function loadFilter(interfaceVersion, isDevBuild)
    GetBuildInfo = function()
        return "12.0.7", "68887", "Jul 23 2026", interfaceVersion
    end

    local HA = {
        __isDevBuild = isDevBuild,
        Addon = { db = { global = {} } },
    }
    assert(loadfile(root .. "/UI/VendorFilter.lua"))("Homestead", HA)
    return HA.VendorFilter
end

local unreleasedVendor = { npcID = 999001, name = "Test Unreleased", unreleased = true }

-- 1. A packaged release never reveals, however new the client is. This is the
--    case that protects players; if only one of these assertions survives a
--    future refactor, it should be this one.
local filter = loadFilter(PTR_INTERFACE, nil)
assert(filter.ShouldRevealUnreleasedVendors() == false,
    "release build on a 12.1 client must not reveal unreleased vendors")
assert(filter.ShouldHideVendor(unreleasedVendor) == true,
    "release build on a 12.1 client must hide unreleased vendors")

-- 2. A dev build on a client that predates the content still hides it —
--    otherwise daily retail dev work is cluttered with pins for vendors that
--    are not in the game yet.
filter = loadFilter(RETAIL_INTERFACE, true)
assert(filter.ShouldRevealUnreleasedVendors() == false,
    "dev build on a 12.0.7 client must not reveal 12.1 vendors")
assert(filter.ShouldHideVendor(unreleasedVendor) == true,
    "dev build on a 12.0.7 client must hide 12.1 vendors")

-- 3. Both conditions met: this is the PTR scanning session the ticket exists for.
filter = loadFilter(PTR_INTERFACE, true)
assert(filter.ShouldRevealUnreleasedVendors() == true,
    "dev build on a 12.1 client must reveal 12.1 vendors")
assert(filter.ShouldHideVendor(unreleasedVendor) == false,
    "dev build on a 12.1 client must show 12.1 vendors")

-- 4. `removed` is not `unreleased`. A retired vendor stays hidden on the one
--    build where the reveal is otherwise wide open. Dershway [151941] was
--    tombstoned with `unreleased` and would have come back on 12.1 had the two
--    meanings stayed merged.
local removedVendor = { npcID = 151941, name = "Test Removed", removed = true }
assert(filter.ShouldHideVendor(removedVendor) == true,
    "removed vendors must stay hidden on a dev build of a shipped client")

-- 5. ...including when the vendor also looks like an event vendor, which is the
--    escape hatch Dershway's `expansion = "Events"` would have suggested.
local removedEventVendor = {
    npcID = 151941, name = "Test Removed Event", removed = true, _isEventVendor = true,
}
assert(filter.ShouldHideVendor(removedEventVendor) == true,
    "removed vendors must not escape through the event-vendor branch")

print("hs245_unreleased_reveal: OK")
