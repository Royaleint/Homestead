-- luacheck: globals assert io package print
-- Run from the repo root:  lua tests/hs538_locale_keys.lua [root]

local root = (... or "."):gsub("\\\\", "/"):gsub("/+$", "")

-------------------------------------------------------------------------------
-- Every text the Decor Browser looks up through L exists in enUS and in each other
-- locale file, so no player sees a key that was never added. The one exception is a
-- key enUS reads from a Blizzard string (L["x"] = GLOBAL or "x"): the client already
-- translates it, so the other files leave it out. The Options entries for the browser
-- are read outside UI/Browser and are listed here.
-------------------------------------------------------------------------------

local LOCALES = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local OUTSIDE = { "Decor Browser", "Show 3D preview", "desc_browser_model3d" }

local function readFile(path)
    local f = assert(io.open(root .. "/" .. path, "rb"), "cannot open " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

local function listLua(dir)
    local windows = package.config:sub(1, 1) == "\\"
    local path = root .. "/" .. dir
    local pipe = assert(io.popen(windows and ('dir /b "' .. path:gsub("/", "\\") .. '"') or ('ls "' .. path .. '"')))
    local names = {}
    for name in pipe:lines() do
        name = name:gsub("\r", "")
        if name:match("%.lua$") then names[#names + 1] = name end
    end
    pipe:close()
    assert(#names > 0, "no Lua files found in " .. dir)
    return names
end

local used = {}
for _, name in ipairs(listLua("UI/Browser")) do
    for key in readFile("UI/Browser/" .. name):gmatch('%f[%w_]L%["(.-)"%]') do used[key] = true end
end
for _, key in ipairs(OUTSIDE) do used[key] = true end

local defined, blizzard = {}, {}
for _, locale in ipairs(LOCALES) do
    defined[locale] = {}
    for line in readFile("Locale/" .. locale .. ".lua"):gmatch("[^\r\n]+") do
        local key, rest = line:match('^%s*L%["(.-)"%]%s*=%s*(.*)$')
        if key then
            defined[locale][key] = true
            if locale == "enUS" and rest:match('^[A-Z][A-Z0-9_]*%s+or%s+"') then blizzard[key] = true end
        end
    end
end

local missing, count = {}, 0
for key in pairs(used) do
    count = count + 1
    for _, locale in ipairs(LOCALES) do
        if not defined[locale][key] and not (locale ~= "enUS" and blizzard[key]) then
            missing[#missing + 1] = locale .. ': L["' .. key .. '"]'
        end
    end
end
table.sort(missing)

assert(count > 100, "found too few browser keys (" .. count .. ")")
assert(#missing == 0, "keys missing from a locale file:\n  " .. table.concat(missing, "\n  "))
print("hs538_locale_keys: ok (" .. count .. " keys in " .. #LOCALES .. " locale files)")
