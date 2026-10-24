-- luacheck: globals assert loadfile print CreateFrame string io
-- Run from the repo root:  lua tests/hs538_wallet.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-- Lua 5.1's string.format has no "%n$" specifiers; WoW's takes them (Blizzard ships "%3$d/%2$d/20%4$02d").
-- Test-only: rewrite them as plain specifiers and put the arguments in the named order.
local format = string.format
function string.format(fmt, ...)
    if not fmt:find("%%%d+%$") then return format(fmt, ...) end
    local args, order = { ... }, {}
    local plain = fmt:gsub("%%(%d+)%$", function(n)
        order[#order + 1] = args[tonumber(n)]
        return "%"
    end)
    return format(plain, unpack(order))
end
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The wallet events through the real router, window, pages and CanGet: money, a currency or a bag change
-- judges the walk's offers again without a new walk; nothing changed repaints nothing; a burst is one
-- re-judge; the account-data event only draws again; a hidden browser listens to none of them.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local WALLET_EVENTS = { "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE_DELAYED",
    "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED" }

-- A world with the Decor Browser open on Summary. Every frame records the events it registers. Player gold
-- is 250: Oak Bench (300) is short, the rest of the standard world is affordable. Coin Lamp costs 5 of
-- currency 700 (the player holds 1) and Token Vase 2 of item 500 (the player holds 0).
local function world(bare, before)
    local env = newWorld(root, { realWindow = true })
    env.prewarm = 0
    env.HA.BadgeCalculation = {
        PeekVendorStats = function() return nil end,
        RequestPrewarm = function() env.prewarm = env.prewarm + 1 end,
    }
    local make = CreateFrame
    CreateFrame = function(...)
        local f = make(...)
        f.registered = {}
        f.RegisterEvent = function(self, name) self.registered[name] = true end
        f.UnregisterAllEvents = function(self) self.registered = {} end
        return f
    end
    local s = env.standard()
    if not bare then
        env.decor(70, "Coin Lamp")
        env.sell(70, s.anna, { currencies = { { id = 700, amount = 5 } } })
        env.decor(71, "Token Vase")
        env.sell(71, s.anna, { items = { { id = 500, amount = 2 } } })
    end
    env.money, env.currency[700], env.count[500] = 250, { quantity = 1 }, 0
    env.s = s
    if before then before(env, s) end
    env.reasons, env.dropped = {}, 0
    for _, page in ipairs(env.pageList) do
        local refresh = page.Refresh
        function page.Refresh(self, reason)
            env.reasons[#env.reasons + 1] = reason
            return refresh(self, reason)
        end
    end
    env.open()
    env.flush()
    local invalidate = env.D.InvalidateMemos
    function env.D.InvalidateMemos()
        env.dropped = env.dropped + 1
        return invalidate()
    end
    env.reasons, env.reqCalls = {}, 0
    local requirements = env.D.Requirements
    function env.D.Requirements(...)
        env.reqCalls = env.reqCalls + 1
        return requirements(...)
    end
    return env
end

local function at(env, id)
    for i, v in ipairs((env.catalogList())) do if v == id then return i end end
end

local function listener(env)
    for _, f in ipairs(env.all) do
        if f.registered and f.registered.PLAYER_MONEY then return f end
    end
end

local function fire(env, event, ...)
    local f = listener(env)
    assert(f and f.registered[event], event .. " is not registered on a shown browser")
    f.scripts.OnEvent(f, event, ...)
end

local function rejudges(env)
    local n = 0
    for _, op in ipairs(env.measured) do if op == "browser_rejudge" then n = n + 1 end end
    return n
end

-- Money moves an item from short to can after one coalesced refresh: no new memo, no new walk, and the
-- ranking, the vendor counts, the item states and the Catalog rows are rebuilt.
do
    local env = world()
    local B, CG = env.B, env.CG
    env.go("catalog")
    env.flush()
    eq(B.ItemState(1), "short", "300 against 250 gold is short")
    local ranked = CG.Rank()
    local can = CG.VendorCanCount(env.s.anna)
    assert(at(env, 1) > at(env, 3), "a short item sorts after the locked one that comes first by name")
    eq(env.catalogRow(1).d.state, "short")
    eq(env.catalogRow(1).d.right, "|cffff3333300g|r", "the short part of the price is red")
    local rec = env.catalogRow(1).rec
    local walks, dropped = env.walks(), env.dropped
    env.reasons = {}

    env.money = 1000
    fire(env, "PLAYER_MONEY")
    fire(env, "PLAYER_MONEY")
    eq(#env.timers, 1, "events in a burst share one timer")
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet", "one repaint, for the wallet")
    eq(B.ItemState(1), "can", "the item is now affordable")
    assert(CG.Rank() ~= ranked and #CG.Rank() == #ranked + 1, "the ranking was not rebuilt")
    eq(CG.VendorCanCount(env.s.anna), can + 1, "the vendor count was not rebuilt")
    eq(env.dropped, dropped, "a wallet change must not drop the memos")
    eq(env.walks(), walks, "a wallet change must not walk again")
    eq(rejudges(env), 1)
    assert(at(env, 1) < at(env, 3), "the Catalog orders by the new verdict")
    eq(env.catalogRow(1).rec, rec, "the records are kept, not rebuilt")
    eq(env.catalogRow(1).d.state, "can", "and its rows describe it again")
    eq(env.catalogRow(1).d.right, "300g", "a part that is now covered is red no more")
    print("hs538_wallet: money re-judges without a walk ok")
end

-- A part that turns from short to covered while the item stays short reaches the Catalog's wallet branch
-- too, so the row's price is drawn again with one part red.
do
    local env = world(nil, function(e, s)
        e.decor(72, "Two Part Lamp")
        e.sell(72, s.anna, { gold = 300, currencies = { { id = 700, amount = 5 } } })
    end)
    env.go("catalog")
    env.flush()
    eq(env.catalogRow(72).d.state, "short")
    eq(env.catalogRow(72).d.right, "|cffff3333300g|r + |cffff33335c|r", "both parts are short")
    env.money = 1000
    fire(env, "PLAYER_MONEY")
    env.flush()
    eq(env.reasons[#env.reasons], "wallet", "a changed part is a wallet change, whatever the verdict")
    eq(env.catalogRow(72).d.state, "short", "the item is still short")
    eq(env.catalogRow(72).d.right, "300g + |cffff33335c|r", "only the part still short is red")
    print("hs538_wallet: a covered part stops being red ok")
end

-- A Catalog filtered to Can get now gains the item.
do
    local env = world()
    env.go("catalog", { filters = { canGet = true } })
    env.flush()
    assert(not at(env, 1), "a short item is not in Can get now")
    env.money = 1000
    fire(env, "PLAYER_MONEY")
    env.flush()
    assert(at(env, 1), "the item joins Can get now after the re-judge")
    print("hs538_wallet: Can get now filter gains the item ok")
end

-- The wallet changes while another page is up: the Catalog, shown later, must not keep the old verdicts.
do
    local env = world()
    env.go("catalog")
    env.flush()
    eq(env.catalogRow(1).d.state, "short")
    local rec = env.catalogRow(1).rec
    env.go("summary")
    env.flush()
    env.money = 1000
    fire(env, "PLAYER_MONEY")
    env.flush()
    eq(env.B.ItemState(1), "can", "the Overview side already judges it can")
    env.go("catalog")
    env.flush()
    eq(env.catalogRow(1).rec, rec, "the records are kept")
    eq(env.catalogRow(1).rec.g, 0, "the row's group follows the new verdict")
    eq(env.catalogRow(1).d.state, "can", "the words are described again")
    eq(env.catalogRow(1).d.right, "300g", "no red part is left")
    assert(at(env, 1) < at(env, 3), "the best order is rebuilt")
    print("hs538_wallet: Catalog shown after a wallet change ok")
end

-- The same, returning through Back: the router restores the page and Show still sees the verdicts have moved.
do
    local env = world()
    env.go("catalog")
    env.flush()
    eq(env.catalogRow(1).d.state, "short")
    local rec = env.catalogRow(1).rec
    env.go("summary")
    env.flush()
    env.money = 1000
    fire(env, "PLAYER_MONEY")
    env.flush()
    env.B.Back()
    env.flush()
    eq(env.route.kind, "catalog", "Back returns to the Catalog")
    eq(env.catalogRow(1).rec, rec, "the records are kept")
    eq(env.catalogRow(1).rec.g, 0, "the row's group follows the new verdict")
    eq(env.catalogRow(1).d.state, "can", "the words are described again")
    assert(at(env, 1) < at(env, 3), "the best order is rebuilt")
    print("hs538_wallet: Catalog reached by Back after a wallet change ok")
end

-- A vendor source with no recorded cost shows the price the walk judges by, in every list.
do
    local env = world(nil, function(e, s)
        e.decor(95, "Bare Cost Stool")
        e.sources[95] = { { type = "vendor", data = { npcID = s.anna.npcID, vendor = s.anna, name = s.anna.name } } }
        e.offers[95] = true
        s.anna.items[#s.anna.items + 1] = 95
    end)
    local want = env.D.Price(95, env.s.anna)
    assert(want, "the resolver prices it")
    eq(env.D.ItemSources(95)[1].price, want, "the source carries the resolved price")
    env.go("catalog")
    env.flush()
    eq(env.catalogRow(95).d.right, want, "and the Catalog row shows it")
    print("hs538_wallet: resolved price on a cost-less source ok")
end

-- The Price sort reads the price the row shows: a cost-less source priced by the resolver sorts by that gold,
-- and one the resolver prices in currency has no gold to compare, so it stays behind every gold price.
do
    local env = world(nil, function(e, s)
        e.decor(95, "Bare Cost Stool")
        e.sources[95] = { { type = "vendor", data = { npcID = s.anna.npcID, vendor = s.anna, name = s.anna.name } } }
        e.decor(96, "Bare Token Stool")
        e.sources[96] = { { type = "vendor", data = { npcID = s.anna.npcID, vendor = s.anna, name = s.anna.name } } }
        e.offers[95], e.offers[96] = true, true
        s.anna.items[#s.anna.items + 1] = 95
        s.anna.items[#s.anna.items + 1] = 96
        local priced = {
            [95] = { gold = 5 },
            [96] = { currencies = { { id = 700, amount = 5 } } },
        }
        e.HA.SourceManager.GetVendorItemCost = function(_, itemID) return priced[itemID] or { gold = 100 } end
    end)
    env.go("catalog")
    env.flush()
    local sort
    for _, f in ipairs(env.all) do
        if f.template == "WowStyle1DropdownTemplate" then sort = f end
    end
    sort:TestPick("Price")
    eq(env.catalogList()[1], 95, "the cost-less source priced 5g sorts before the 20g one")
    assert(at(env, 96) > at(env, 1), "a currency price has no gold and sorts after the 300g one")
    print("hs538_wallet: Price sort follows the resolved price ok")
end

-- Summary with fewer than three items to get now: a re-judge asks for each shown row's requirements at most
-- once, not once for every locked candidate in the walk.
do
    local env = world(false, function(e, s)
        for id = 90, 97 do
            e.decor(id, "Locked " .. id)
            e.sell(id, s.anna, { gold = 50 })
            e.reqs[id .. ":100"] = { { type = "unknown", text = "Favor " .. id } }
        end
    end)
    env.money = 0
    fire(env, "PLAYER_MONEY")
    env.flush()
    env.go("summary")
    env.flush()
    env.money = 25
    env.reasons, env.reqCalls = {}, 0
    fire(env, "PLAYER_MONEY")
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet")
    eq(#env.CG.Rank(), 1, "fewer than three items to get now")
    assert(env.reqCalls <= 3, "a re-judge asked for requirements " .. env.reqCalls .. " times")
    print("hs538_wallet: Summary refill stays cheap ok")
end

-- The vendors list counts the item that became affordable, and the refresh asks for no background fill.
do
    local env = world()
    env.go("sources", { type = "vendors" })
    env.flush()
    local function count()
        for _, row in ipairs((env.sourcesList())) do
            if row.key == 100 then return row.arg end
        end
    end
    local before, asked = count(), env.prewarm
    assert(before, "Anna's row says how many can be got now")
    env.reasons = {}
    env.money = 1000
    fire(env, "PLAYER_MONEY")
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet")
    eq(count(), before + 1, "the row's count went up")
    eq(env.prewarm, asked, "a wallet refresh must not ask for the vendor-count fill")
    print("hs538_wallet: vendors list count ok")
end

-- Summary and the item page also draw again for a wallet change.
do
    local env = world()
    for _, key in ipairs({ "summary", "item" }) do
        if key == "item" then env.B.Go({ kind = "item", id = 1 }) else env.go(key) end
        env.flush()
        env.reasons = {}
        env.money = env.money + 1000
        fire(env, "PLAYER_MONEY")
        env.flush()
        eq(table.concat(env.reasons, ","), "wallet", key .. " must be told")
    end
    print("hs538_wallet: Summary and item page draw again ok")
end

-- An unused currency, an unchanged currency and an unchanged bag repaint nothing; a changed bag, a changed
-- currency and a key first read after the walk do.
do
    local env = world()
    local B, CG = env.B, env.CG
    eq(B.ItemState(70), "short")
    eq(B.ItemState(71), "short")
    local ranked, entry, st
    local function snap()
        B.ItemState(1)
        ranked, entry = CG.Rank(), CG.Entry(1)
        st = entry.st
        assert(st, "the entry has a cached state to keep")
    end
    snap()
    local function quiet(msg)
        env.flush()
        eq(#env.reasons, 0, msg)
        eq(CG.Rank(), ranked, msg .. ": the ranking must stay")
        eq(entry.st, st, msg .. ": the entry's state must stay")
    end
    local walks, dropped = env.walks(), env.dropped

    eq(CG.wallet.cur[999], nil)
    fire(env, "CURRENCY_DISPLAY_UPDATE", 999)
    eq(#env.timers, 0, "a currency no offer needs schedules nothing")
    eq(rejudges(env), 0)

    fire(env, "CURRENCY_DISPLAY_UPDATE")
    eq(#env.timers, 1, "an unnamed currency could be a needed one")
    quiet("an unnamed currency that changed nothing")
    eq(rejudges(env), 1)

    fire(env, "CURRENCY_DISPLAY_UPDATE", 700)
    eq(#env.timers, 1, "a needed currency schedules a re-judge")
    quiet("a needed currency whose amount is the same")
    eq(rejudges(env), 2, "it was compared")

    fire(env, "BAG_UPDATE_DELAYED")
    quiet("a bag with the same count")
    eq(rejudges(env), 3)

    env.count[500] = 2
    fire(env, "BAG_UPDATE_DELAYED")
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet", "a changed count repaints")
    eq(B.ItemState(71), "can")
    snap()
    env.reasons = {}

    env.currency[700] = { quantity = 9 }
    fire(env, "CURRENCY_DISPLAY_UPDATE", 700)
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet", "a changed currency repaints")
    eq(B.ItemState(70), "can")
    snap()
    env.reasons = {}

    eq(env.dropped, dropped, "none of it dropped the memos")
    eq(env.walks(), walks, "none of it walked again")
    print("hs538_wallet: relevance and unchanged wallets ok")
end

-- With no offer needing a currency, an unnamed currency update schedules nothing.
do
    local env = world(true)
    eq(next(env.CG.wallet.cur), nil)
    fire(env, "CURRENCY_DISPLAY_UPDATE")
    eq(#env.timers, 0, "no needed currency, nothing to judge")
    print("hs538_wallet: unnamed currency ok")
end

-- Twenty bag events in a burst are one re-judge, and the account-data event only draws again.
do
    local env = world()
    local walks, dropped = env.walks(), env.dropped
    for i = 1, 20 do
        env.count[500] = i % 3
        fire(env, "BAG_UPDATE_DELAYED")
    end
    eq(#env.timers, 1, "twenty bag events share one timer")
    env.flush()
    eq(rejudges(env), 1, "and make one re-judge")

    env.reasons = {}
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    eq(#env.timers, 1)
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet", "account data draws again")
    eq(rejudges(env), 1, "without judging again")
    eq(env.dropped, dropped)
    eq(env.walks(), walks)
    print("hs538_wallet: debounce and account data ok")
end

-- A shown browser listens to the four events; a closed one, and one never opened, listen to none, and a
-- pending refresh dies with the window.
do
    local env = newWorld(root, { realWindow = true })
    env.standard()
    assert(not listener(env), "a browser never opened registers nothing")
    local env2 = world()
    local f = listener(env2)
    for _, name in ipairs(WALLET_EVENTS) do assert(f.registered[name], name .. " is not registered while shown") end
    fire(env2, "PLAYER_MONEY")
    local pending = env2.timers[#env2.timers]
    env2.B:Close()
    env2.B.Window.frame:Hide()
    assert(pending.cancelled, "the pending refresh must be cancelled by the close")
    for _, frame in ipairs(env2.all) do
        for _, name in ipairs(WALLET_EVENTS) do
            assert(not (frame.registered and frame.registered[name]), name .. " is still registered while hidden")
        end
    end
    env2.reasons = {}
    env2.flush()
    eq(#env2.reasons, 0, "a hidden browser repaints nothing")
    print("hs538_wallet: hidden browser registers none ok")
end

-- Another character holds the missing currency. Coin Lamp needs 5 of currency 700 and the player holds 1.
local function holders(env, mine, alt, other)
    env.account.ready = true
    env.account.rows[700] = {
        { characterGUID = "Player-1", characterName = "Me", fullCharacterName = "Me-Realm", quantity = mine },
        { characterGUID = "G2", characterName = "Alt", fullCharacterName = "Alt-Realm", quantity = alt },
        { characterGUID = "G3", characterName = "Other", fullCharacterName = "Other-Realm", quantity = other },
    }
end

local function hint(env, text)
    local _, words = env.B.ItemState(70)
    local muted = env.B.Style.Muted(text)
    eq(words:sub(-#muted), muted, "the hint is muted and last: " .. tostring(words))
end

-- The item page's second lines (the status of each source row), top to bottom.
local function statusLines(env)
    local lines = {}
    for _, f in ipairs(env.all) do
        if f.two and f.two.shown and env.ownerKind(f) == "item" then lines[#lines + 1] = f.two.text end
    end
    return table.concat(lines, " | ")
end

do
    local env = world(nil, function(e) e.account.transferable[700] = true end)
    eq(env.account.requests, 1, "one request when a short part is a transferable currency")
    local state, words = env.B.ItemState(70)
    eq(state, "short")
    assert(not words:find("has"), "no data yet: no hint")
    eq(env.account.fetches, 0, "not ready: nothing is fetched")

    holders(env, 50, 12000, 300)
    local rejudged = rejudges(env)
    env.reasons = {}
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    eq(table.concat(env.reasons, ","), "wallet", "the data event draws again")
    eq(rejudges(env), rejudged, "without judging again")
    hint(env, "(Alt has 12000)")
    eq(env.CG.ShortWords({ currencies = { { id = 700, amount = 5 } } }), select(2, env.B.ItemState(70)))
    local fetches = env.account.fetches
    for _ = 1, 3 do env.CG.ShortWords({ currencies = { { id = 700, amount = 5 } } }) end
    env.B.ItemState(70)
    eq(env.account.fetches, fetches, "the fetch is kept until the next data event or wallet refresh")

    local _, gold = env.B.ItemState(1)
    assert(not gold:find("has"), "a gold cost gets no hint")
    local state71, item = env.B.ItemState(71)
    eq(state71, "short")
    assert(not (item or ""):find("has"), "an item cost gets no hint")

    env.B.Go({ kind = "item", id = 70 })
    env.flush()
    local S = env.B.Style
    local vendorState, vendorWords = env.B.ItemState(70, 100)
    eq(vendorState, "short")
    local line = statusLines(env)
    assert(line:find(S.Colored(S.color.stop, "Not enough: " .. vendorWords), 1, true), "the item page row says: " .. line)
    local hintAt = vendorWords:find(S.Muted("(Alt has 12000)"), 1, true)
    assert(hintAt and vendorWords:sub(1, hintAt - 1):find("5c", 1, true), "the red parts come first, the muted hint after: " .. vendorWords)
    assert(line:find(S.Muted("(Alt has 12000)") .. "|r", 1, true), "and the row closes after the hint: " .. line)

    env.account.rows[700][2].quantity = 13000
    env.currency[700] = { quantity = 2 }
    fire(env, "CURRENCY_DISPLAY_UPDATE", 700)
    env.flush()
    hint(env, "(Alt has 13000)")
    eq(env.account.requests, 1, "a request at most once per show")
    env.money = 1
    fire(env, "PLAYER_MONEY")
    env.flush()
    eq(env.account.requests, 1)

    env.B:Close()
    env.B.Window.frame:Hide()
    env.B:Open()
    env.flush()
    eq(env.account.requests, 2, "a new show asks again")
    print("hs538_wallet: other-character hint ok")
end

-- Account data lands while another page is up: the Catalog, shown later, describes its row with the hint.
do
    local env = world(nil, function(e) e.account.transferable[700] = true end)
    env.go("catalog")
    env.flush()
    assert(not (env.catalogRow(70).d.arg or ""):find("has"), "no data yet: no hint")
    env.go("summary")
    env.flush()
    holders(env, 50, 12000, 300)
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    env.go("catalog")
    env.flush()
    local arg = env.catalogRow(70).d.arg or ""
    local muted = env.B.Style.Muted("(Alt has 12000)")
    eq(arg:sub(-#muted), muted, "the row carries the hint: " .. arg)
    print("hs538_wallet: Catalog shown after account data ok")
end

-- The player is dropped, the largest holding above 0 wins, a shared name shows in full, and an empty or
-- unreadable result is no hint.
do
    local env = world(nil, function(e) e.account.transferable[700] = true end)
    holders(env, 99999, 12000, 300)
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    hint(env, "(Alt has 12000)")

    env.account.rows[700][3].characterName = "Alt"
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    hint(env, "(Alt-Realm has 12000)")

    env.account.rows[700][2].quantity, env.account.rows[700][3].quantity = 0, 7
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    hint(env, "(Other-Realm has 7)")

    env.account.rows[700][3].quantity = 0
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    assert(not select(2, env.B.ItemState(70)):find("has"), "every other character at 0: no hint")

    env.account.rows[700] = nil
    fire(env, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
    env.flush()
    assert(not select(2, env.B.ItemState(70)):find("has"), "nothing returned: no hint")
    print("hs538_wallet: holder choice ok")
end

-- A currency that is not transferable, or no short currency at all, asks for nothing and fetches nothing.
do
    local env = world(nil, function(e) holders(e, 50, 12000, 300) end)
    eq(env.account.requests, 0, "not transferable: no request")
    assert(not select(2, env.B.ItemState(70)):find("has"), "not transferable: no hint")
    eq(env.account.fetches, 0, "and no fetch")
    local bare = world(true, function(e) e.account.transferable[700] = true holders(e, 50, 12000, 300) end)
    eq(bare.account.requests, 0, "no short currency: no request")
    eq(bare.account.fetches, 0)
    print("hs538_wallet: no hint without a transferable short currency ok")
end

-- Only a reachable offer that is short in a transferable currency asks. A locked or other-faction offer is
-- short too, and its price is drawn red, but it asks for nothing. A reachable short offer asks exactly once.
do
    local function asks(setup)
        local env = world(true, function(e, s)
            e.account.transferable[700] = true
            e.decor(80, "Test Piece")
            setup(e, s)
        end)
        env.go("catalog")
        env.flush()
        env.B.Go({ kind = "item", id = 80 })
        env.flush()
        env.go("summary")
        env.flush()
        return env.account.requests
    end
    local cost = { currencies = { { id = 700, amount = 5 } } }
    eq(asks(function(e, s)
        e.sell(80, s.anna, cost)
        e.reqs["80:100"] = { { type = "unknown", text = "Mysterious Favor" } }
    end), 0, "a locked offer asks for nothing")
    eq(asks(function(e, s) e.sell(80, s.cora, cost) end), 0, "an other-faction offer asks for nothing")
    eq(asks(function(e, s) e.sell(80, s.anna, cost) end), 1, "a reachable short offer asks once")
    print("hs538_wallet: only reachable short offers ask ok")
end

-- The restricted transfer call is never named by the addon.
do
    local needle = "RequestCurrency" .. "FromAccountCharacter"
    local toc = assert(io.open(root .. "/Homestead.toc", "rb"))
    local text = toc:read("*a")
    toc:close()
    local files = 0
    for path in text:gmatch("[^\r\n]+") do
        if path:find("%.lua%s*$") and not path:find("^#") then
            local f = assert(io.open(root .. "/" .. path:gsub("\\", "/"):gsub("%s+$", ""), "rb"), path)
            assert(not f:read("*a"):find(needle, 1, true), path .. " names the transfer call")
            f:close()
            files = files + 1
        end
    end
    assert(files > 50, "the TOC scan found too few files")
    print("hs538_wallet: transfer call never named ok")
end

-- A positional string renders in the native suite.
eq(("(%1$s has %2$s)"):format("Alt", 12000), "(Alt has 12000)")
eq(("%2$s-%1$s"):format("a", "b"), "b-a", "the shim reorders")

print("hs538_wallet: all ok")
