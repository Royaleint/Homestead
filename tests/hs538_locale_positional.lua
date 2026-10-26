-- luacheck: globals assert loadfile loadstring print io
-- Run from the repo root:  lua tests/hs538_locale_positional.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- locale_lint compares placeholders between enUS and a translation. Positional ones ("%1$s") may be
-- reordered; plain ones keep their order; the same tokens must still all be there. The two functions are
-- loaded from the lint script itself, so the fixtures judge the code that runs.
-------------------------------------------------------------------------------

local f = assert(io.open(root .. "/tests/locale_lint.lua", "rb"))
local text = f:read("*a")
f:close()
local first = assert(text:find("local function tokens", 1, true), "tokens() not found")
local last = assert(text:find("-- TOC discovery.", first, true), "end of sameTokens() not found")
local sameTokens = assert(loadstring(text:sub(first, last - 1) .. "\nreturn sameTokens", "=locale_lint"))()

local function check(a, b, want, msg)
    if sameTokens(a, b) ~= want then error(msg .. ": " .. a .. " | " .. b, 2) end
end

local EN = "(%1$s has %2$s)"
check(EN, "(%1$s hat %2$s)", true, "the same order")
check(EN, "(%2$s bei %1$s)", true, "reordered positional tokens")
check(EN, "(%1$s hat)", false, "a positional token is missing")
check(EN, "(%1$s hat %2$s %2$s)", false, "a positional token is repeated")
check(EN, "(%1$s hat %3$s)", false, "a different argument")
check(EN, "(%1$s hat %2$d)", false, "a different conversion")
check(EN, "(%1$s hat %s)", false, "a plain token in place of a positional one")
check("%s of %s", "%s von %s", true, "plain tokens in order")
check("%d of %s", "%s von %d", false, "plain tokens reordered")
check("%s: %1$s %2$d", "%s: %2$d %1$s", false, "plain and positional mixed")
check("%1$s: %s", "%1$s: %s", false, "a mix is refused even when identical")
check("%s", "%1$s", false, "plain against positional")
check("%1$s %d", "%1$s %s", false, "a plain token changed")
check("100%% %1$s", "100%% %1$s", true, "an escaped percent")
check("|cffffffff%1$s|r", "%1$s", false, "a colour escape is missing")
print("hs538_locale_positional: all ok")
