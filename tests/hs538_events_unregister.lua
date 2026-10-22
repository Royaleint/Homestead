-- luacheck: globals assert loadfile print

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Loads the real Core/events.lua and pins per-callback removal and
-- registration while an event is being delivered: a change made during a
-- dispatch never alters the list that dispatch is iterating, and takes
-- effect from the next one.
-------------------------------------------------------------------------------

local function newEvents()
    local HA = { Addon = { Debug = function() end } }
    assert(loadfile(root .. "/Core/events.lua"))("Homestead", HA)
    return HA.Events
end

local function recorder()
    local calls = {}
    local function make(tag, extra)
        return function()
            calls[#calls + 1] = tag
            if extra then extra() end
        end
    end
    local function take()
        local s = table.concat(calls, ",")
        for i = #calls, 1, -1 do calls[i] = nil end
        return s
    end
    return make, take
end

-- E1: removing a callback during Fire keeps the dispatch in progress whole;
-- the next Fire skips it. Covers removing a later callback and removing itself.
do
    local Events = newEvents()
    local make, take = recorder()
    local b
    local a = make("a", function() Events:UnregisterCallback("TEST_EVENT", b) end)
    b = make("b")
    local c
    c = make("c", function() Events:UnregisterCallback("TEST_EVENT", c) end)
    Events:RegisterCallback("TEST_EVENT", a)
    Events:RegisterCallback("TEST_EVENT", b)
    Events:RegisterCallback("TEST_EVENT", c)

    Events:Fire("TEST_EVENT")
    assert(take() == "a,b,c", "a removal during Fire must not disturb the dispatch in progress")
    Events:Fire("TEST_EVENT")
    assert(take() == "a", "the next Fire must skip every callback removed during the last one")
    print("hs538_events_unregister: E1 removal during Fire ok")
end

-- E2: registering during Fire does not run the new callback in that
-- dispatch; the next Fire does, after the existing ones in insertion order.
do
    local Events = newEvents()
    local make, take = recorder()
    local d = make("d")
    local added = false
    local a = make("a", function()
        if not added then
            added = true
            Events:RegisterCallback("TEST_EVENT", d)
        end
    end)
    Events:RegisterCallback("TEST_EVENT", a)
    Events:RegisterCallback("TEST_EVENT", make("b"))
    Events:RegisterCallback("TEST_EVENT", make("c"))

    Events:Fire("TEST_EVENT")
    assert(take() == "a,b,c", "a callback registered during Fire must not run in that dispatch")
    Events:Fire("TEST_EVENT")
    assert(take() == "a,b,c,d", "the next Fire must run it, after the earlier callbacks in insertion order")
    print("hs538_events_unregister: E2 registration during Fire ok")
end

-- E3: other callbacks survive a removal; removing an unknown callback or from
-- an unknown name is a no-op; a callback registered twice is removed entirely.
do
    local Events = newEvents()
    local make, take = recorder()
    local a, b, c = make("a"), make("b"), make("c")
    Events:RegisterCallback("TEST_EVENT", a)
    Events:RegisterCallback("TEST_EVENT", b)
    Events:RegisterCallback("TEST_EVENT", c)
    Events:RegisterCallback("OTHER_EVENT", b)

    Events:UnregisterCallback("TEST_EVENT", b)
    Events:Fire("TEST_EVENT")
    assert(take() == "a,c", "removing one callback must leave the others in order")
    Events:Fire("OTHER_EVENT")
    assert(take() == "b", "removal is per name: the same function under another name survives")

    Events:UnregisterCallback("TEST_EVENT", make("x"))
    Events:UnregisterCallback("NEVER_REGISTERED", a)
    Events:Fire("TEST_EVENT")
    assert(take() == "a,c", "removing an unknown callback must change nothing")

    Events:RegisterCallback("TEST_EVENT", a)
    Events:UnregisterCallback("TEST_EVENT", a)
    Events:Fire("TEST_EVENT")
    assert(take() == "c", "a callback registered twice must be removed entirely")

    Events:UnregisterCallbacks("TEST_EVENT")
    Events:Fire("TEST_EVENT")
    assert(take() == "", "UnregisterCallbacks must still clear the whole name")
    print("hs538_events_unregister: E3 other callbacks survive ok")
end

-- E4: update-type names route to the throttled update table for both
-- registration and removal.
do
    local Events = newEvents()
    local make, take = recorder()
    local a, b = make("a"), make("b")
    Events:RegisterCallback("bags", a)
    Events:RegisterCallback("bags", b)

    Events:Fire("bags")
    assert(take() == "", "an update-type callback must not run from Fire")
    Events:ExecuteUpdate("bags")
    assert(take() == "a,b", "an update-type callback must run from ExecuteUpdate")

    Events:UnregisterCallback("bags", a)
    Events:ExecuteUpdate("bags")
    assert(take() == "b", "UnregisterCallback must remove from the update table for an update-type name")
    print("hs538_events_unregister: E4 update-type routing ok")
end

print("hs538_events_unregister: ok")
