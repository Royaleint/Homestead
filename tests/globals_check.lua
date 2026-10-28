-- Global-name and UISpecialFrames check. Plain Lua 5.1, no requires, no network.
--
-- Run from the repo root:  lua tests/globals_check.lua [<repo root>]
--
-- luacheck sees global assignments but not names handed to the game: a named
-- CreateFrame / CreateFont, an XML name="...", or a _G write. This check collects
-- those names from the shipped source and fails on any name that is neither in
-- the `globals = { ... }` block of .luacheckrc nor in ALLOWED_TODAY below. It also
-- fails on any mention of UISpecialFrames: inserting into it taints Blizzard's
-- protected CloseWindows(), and a bare mention is the first step of an insert.
--
-- Shipped source = the files Homestead.toc loads (XML includes followed),
-- minus Libs/ and anything .pkgmeta ignores. tests/ and the dev folders are not
-- in the TOC, so they are never read.
--
-- Limits: this is a text scan, not a Lua parser.
--  * A name built at run time ("Prefix" .. i) or held in a variable that is not a
--    statement-level `NAME = "x"` / `local NAME = "x"` / `T.NAME = "x"` constant in
--    the same file (outside any table constructor, and never reused as a local or
--    parameter) is "unresolved" and fails until its key is listed in UNRESOLVED_TODAY.
--    The list is empty on purpose.
--  * Aliases are not followed: `local G = _G; G.X = 1` and `local CF = CreateFrame`
--    are invisible to the scan.
--  * Named child regions (CreateFontString, CreateTexture, CreateAnimationGroup)
--    also create globals when given a name; only CreateFrame and CreateFont are read.
--  * XML names are compared as written, so "$parentTitle" is reported literally.
--
-- Every failure prints "FAIL (<id>) <path>: <detail>" and the run exits 1.
-- A clean run prints "RESULT: OK" and exits 0.

-- Named globals that exist on main as of 2026-10-28 and are not in .luacheckrc.
-- Do not add to this list; leave new frames unnamed.
local ALLOWED_TODAY = {
	HomesteadExportDialog = true,
	HomesteadOptionsTooltip = true,
	HomesteadOptionsFrame = true,
	HomesteadSettingsPanel = true,
	HomesteadOutputWindow = true,
	HomesteadWelcomeFrame = true,
	HomesteadWhatsNewFrame = true,
	-- XML virtual templates (UI/Browser/Visuals.xml)
	HomesteadDecorBrowserHeader = true,
	HomesteadDecorBrowserFooter = true,
}

-- "<path>: <call>(<argument text>)" keys for calls whose name cannot be resolved statically.
local UNRESOLVED_TODAY = {}

-- luacheck: globals assert loadfile print io os

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")

local fails = {}

local function fail(id, path, detail)
	fails[#fails + 1] = "FAIL (" .. id .. ") " .. path .. ": " .. detail
end

local function finish()
	for i = 1, #fails do
		print(fails[i])
	end
	if #fails > 0 then
		os.exit(1)
	end
	print("RESULT: OK")
	os.exit(0)
end

local function readFile(path)
	local fh = io.open(path, "rb")
	if not fh then
		return nil
	end
	local text = fh:read("*a")
	fh:close()
	return text
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Same-length copy of Lua 5.1 source with comment bytes turned into spaces
-- (newlines kept), so byte offsets still match. Strings are walked so a "--"
-- inside one is not a comment; string contents are left as written.
local function blankComments(text)
	local n, i, pos, out = #text, 1, 1, {}
	while true do
		local s = text:find("[-\"'%[]", i)
		if not s then
			break
		end
		local c = text:sub(s, s)
		if c == "-" then
			if text:sub(s, s + 1) == "--" then
				local level = text:match("^%-%-%[(=*)%[", s)
				local e
				if level then
					local _, closeEnd = text:find("]" .. level .. "]", s + 4 + #level, true)
					e = closeEnd or n
				else
					e = (text:find("\n", s, true) or n + 1) - 1
				end
				out[#out + 1] = text:sub(pos, s - 1)
				out[#out + 1] = (text:sub(s, e):gsub("[^\n]", " "))
				pos, i = e + 1, e + 1
			else
				i = s + 1
			end
		elseif c == "[" then
			local level = text:match("^%[(=*)%[", s)
			if level then
				local _, closeEnd = text:find("]" .. level .. "]", s + 2 + #level, true)
				i = (closeEnd or n) + 1
			else
				i = s + 1
			end
		else
			local j = s + 1
			while j <= n do
				local d = text:sub(j, j)
				if d == "\\" then
					j = j + (text:sub(j + 1, j + 2) == "\r\n" and 3 or 2)
				elseif d == c then
					break
				elseif d == "\n" then
					j = j - 1
					break
				else
					j = j + 1
				end
			end
			i = j + 1
		end
	end
	out[#out + 1] = text:sub(pos)
	return table.concat(out)
end

-- Top-level arguments of the call whose "(" is at `open`, as trimmed source
-- text; stops after `max` arguments or at the closing paren.
local function callArgs(text, open, max)
	local args, depth, start, i, n = {}, 0, open + 1, open, #text
	while i < n and #args < max do
		i = i + 1
		local c = text:sub(i, i)
		if c == '"' or c == "'" then
			local j = i + 1
			while j <= n and text:sub(j, j) ~= c do
				j = j + (text:sub(j, j) == "\\" and 2 or 1)
			end
			i = j
		elseif c == "(" or c == "{" or c == "[" then
			depth = depth + 1
		elseif c == ")" or c == "}" or c == "]" then
			if depth == 0 then
				args[#args + 1] = trim(text:sub(start, i - 1))
				return args
			end
			depth = depth - 1
		elseif c == "," and depth == 0 then
			args[#args + 1] = trim(text:sub(start, i - 1))
			start = i + 1
		end
	end
	return args
end

local function literal(arg)
	if not arg then
		return nil
	end
	return arg:match('^"([^"\\]*)"$') or arg:match("^'([^'\\]*)'$")
end

-- Brace depth at the start of each line, counted on code with string contents
-- and comments removed.
local function depthByLine(code)
	local bare = code:gsub('"[^"\\\n]*"', '""'):gsub("'[^'\\\n]*'", "''")
	local depths, depth, n = {}, 0, 0
	for line in (bare .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		depths[n] = depth
		for c in line:gmatch("[{}]") do
			depth = depth + (c == "{" and 1 or -1)
		end
	end
	return depths
end

-- name -> string constant, for statement-level `NAME = "x"`, `local NAME = "x"`
-- and `T.NAME = "x"` (a whole line, outside any table constructor). A name that
-- is assigned two different strings, or is also declared as a parameter, loop
-- variable or another local in the file, is dropped (ambiguous).
local function constants(code)
	local depths = depthByLine(code)
	local map, bad, n = {}, {}, 0
	for line in (code .. "\n"):gmatch("([^\n]*)\n") do
		n = n + 1
		if depths[n] == 0 then
			local lhs, value = line:match('^%s*local%s+([%a_][%w_]*)%s*=%s*"([^"\\]*)"%s*;?%s*$')
			if not lhs then
				lhs, value = line:match('^%s*([%a_][%w_%.]*)%s*=%s*"([^"\\]*)"%s*;?%s*$')
			end
			if lhs then
				local key = lhs:match("([%w_]+)$")
				if map[key] ~= nil and map[key] ~= value then
					bad[key] = true
				end
				map[key] = value
			end
		end
	end
	local function shadow(list)
		for id in list:gmatch("[%a_][%w_]*") do
			if map[id] ~= nil then
				bad[id] = true
			end
		end
	end
	for params in code:gmatch("function%s*[%w_%.:]*%s*%(([^)]*)%)") do
		shadow(params)
	end
	for list in code:gmatch("%f[%w_]for%s+([%w_,%s]-)%s+in%f[%W]") do
		shadow(list)
	end
	for list in code:gmatch("%f[%w_]for%s+([%a_][%w_]*)%s*=") do
		shadow(list)
	end
	-- A second `local NAME` anywhere (the constant's own line counts once), or
	-- NAME as a later name in a `local a, NAME` list.
	local seenLocal = {}
	for list in code:gmatch("%f[%w_]local%s+([%a_][%w_,%s]*)") do
		local first = true
		for id in list:gmatch("[%a_][%w_]*") do
			if id == "function" then
				break
			end
			if map[id] ~= nil then
				seenLocal[id] = (seenLocal[id] or 0) + 1
				if seenLocal[id] > 1 or not first then
					bad[id] = true
				end
			end
			first = false
		end
	end
	for key in pairs(bad) do
		map[key] = nil
	end
	return map
end

-- Is the access that ends at `pos` (just past `_G.x` or `_G[...]`) an assignment
-- target? Covers `_G.A = v` and every target of `_G.A, _G.B = 1, 2`.
local function isTarget(code, pos)
	local i, n = pos, #code
	while true do
		i = code:find("%S", i) or n + 1
		local c = code:sub(i, i)
		if c == "=" then
			return code:sub(i + 1, i + 1) ~= "="
		elseif c ~= "," then
			return false
		end
		-- Another assignment target must follow: a name with .field / [index] parts.
		i = code:find("%S", i + 1) or n + 1
		local id = code:match("^[%a_][%w_]*", i)
		if not id then
			return false
		end
		i = i + #id
		while true do
			local field = code:match("^%.[%a_][%w_]*", i)
			if field then
				i = i + #field
			elseif code:sub(i, i) == "[" then
				local depth, j = 1, i + 1
				while j <= n and depth > 0 do
					local d = code:sub(j, j)
					depth = depth + (d == "[" and 1 or d == "]" and -1 or 0)
					j = j + 1
				end
				i = j
			else
				break
			end
		end
	end
end

-- Scans one Lua file. Returns { names = { {name, how} }, unresolved = { {key, line} },
-- special = { line } }.
local function scanLua(text)
	local code = blankComments(text)
	local consts = constants(code)
	local out = { names = {}, unresolved = {}, special = {} }

	local function lineOf(pos)
		local _, count = code:sub(1, pos):gsub("\n", "")
		return count + 1
	end

	local function record(arg, how, pos)
		local name = literal(arg)
		if name then
			out.names[#out.names + 1] = { name = name, how = how }
			return
		end
		local resolved = arg and arg:match("^[%a_][%w_%.]*$") and consts[arg:match("([%w_]+)$")]
		if resolved then
			out.names[#out.names + 1] = { name = resolved, how = how }
		else
			out.unresolved[#out.unresolved + 1] = { key = how .. "(" .. tostring(arg) .. ")", line = lineOf(pos) }
		end
	end

	-- CreateFrame(type, name, ...) and CreateFont(name)
	for _, spec in ipairs({ { "CreateFrame", 2 }, { "CreateFont", 1 } }) do
		local fn, index = spec[1], spec[2]
		local init = 1
		while true do
			local s, e = code:find("%f[%w_]" .. fn .. "%s*%(", init)
			if not s then
				break
			end
			local arg = callArgs(code, e, index)[index]
			if arg ~= nil and arg ~= "nil" then
				record(arg, fn, s)
			end
			init = e + 1
		end
	end

	-- _G.X = v   _G["X"] = v   _G[expr] = v   and every target of a multiple assignment
	local init = 1
	while true do
		local s, e = code:find("%f[%w_]_G%s*[%.%[]", init)
		if not s then
			break
		end
		local arg, after
		if code:sub(e, e) == "." then
			arg = code:match("^[%a_][%w_]*", e + 1)
			if arg then
				after = e + 1 + #arg
				arg = '"' .. arg .. '"'
			end
		else
			local depth, i, n = 1, e + 1, #code
			while i <= n and depth > 0 do
				local c = code:sub(i, i)
				depth = depth + (c == "[" and 1 or c == "]" and -1 or 0)
				i = i + 1
			end
			arg, after = trim(code:sub(e + 1, i - 2)), i
		end
		if arg and isTarget(code, after) then
			record(arg, "_G write", s)
		end
		init = e + 1
	end

	-- rawset(_G, name, v)
	init = 1
	while true do
		local s, e = code:find("%f[%w_]rawset%s*%(%s*_G%s*,", init)
		if not s then
			break
		end
		record(callArgs(code, code:find("(", s, true), 2)[2], "rawset(_G)", s)
		init = e + 1
	end

	-- Any mention of UISpecialFrames, including a string key such as _G["UISpecialFrames"].
	init = 1
	while true do
		local s = code:find("UISpecialFrames", init, true)
		if not s then
			break
		end
		out.special[#out.special + 1] = "line " .. lineOf(s)
		init = s + 1
	end

	return out
end

local function stripXmlComments(text)
	return (text:gsub("<!%-%-.-%-%->", function(c)
		return (c:gsub("[^\n]", " "))
	end))
end

-- Scans one XML file. Returns the name="..." attributes, the file="..." includes,
-- the Lua text of inline <Scripts>/<Script> bodies, and whether the comment-free
-- XML mentions UISpecialFrames anywhere.
local function scanXml(text)
	local plain = stripXmlComments(text)
	local names, includes, bodies = {}, {}, {}
	for _, name in plain:gmatch("%sname%s*=%s*([\"'])(.-)%1") do
		names[#names + 1] = { name = name, how = "XML name" }
	end
	for tag, file in plain:gmatch("<(%a+)[^>]-%sfile%s*=%s*\"([^\"]*)\"") do
		if tag == "Include" or tag == "Script" then
			includes[#includes + 1] = file
		end
	end
	-- Inline Lua: the inside of every <Scripts> block, and <Script> without file=.
	local function body(inner)
		inner = inner:gsub("<!%[CDATA%[", ""):gsub("%]%]>", "")
		inner = inner:gsub("</?%a[^>]*>", "\n")
		inner = inner:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")
		bodies[#bodies + 1] = inner
	end
	for inner in plain:gmatch("<Scripts>(.-)</Scripts>") do
		body(inner)
	end
	for attrs, inner in plain:gmatch("<Script(%f[%s>][^>]*)>(.-)</Script>") do
		if not attrs:find("file%s*=") then
			body(inner)
		end
	end
	return { names = names, includes = includes, bodies = bodies, special = plain:find("UISpecialFrames", 1, true) ~= nil }
end

local function normalize(path)
	path = path:gsub("\\", "/")
	local parts = {}
	for part in path:gmatch("[^/]+") do
		if part == ".." then
			parts[#parts] = nil
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end
	return table.concat(parts, "/")
end

local function dirOf(path)
	return path:match("^(.*)/[^/]*$") or ""
end

-- Entries from the `ignore:` list in .pkgmeta (plain paths; "*.x" patterns do not
-- name a shipped source file here and are skipped).
local function pkgmetaIgnores(text)
	local list, inList = {}, false
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		line = line:gsub("\r$", "")
		if line:match("^ignore:") then
			inList = true
		elseif inList then
			local item = line:match("^%s*%-%s*(.-)%s*$")
			if item then
				item = item:gsub("%s+#.*$", ""):gsub('^"(.*)"$', "%1")
				if not item:find("*", 1, true) then
					list[#list + 1] = normalize(item)
				end
			elseif line:match("^%S") then
				inList = false
			end
		end
	end
	return list
end

local function isIgnored(path, ignores)
	if path:find("^Libs/") then
		return true
	end
	for _, entry in ipairs(ignores) do
		if path == entry or path:sub(1, #entry + 1) == entry .. "/" then
			return true
		end
	end
	return false
end

-- Globals declared in the `globals = { ... }` block of .luacheckrc (not read_globals).
local function luacheckGlobals(text)
	local code = text:gsub("%-%-[^\n]*", "")
	local block = code:match("\nglobals%s*=%s*(%b{})") or code:match("^globals%s*=%s*(%b{})")
	local set = {}
	for name in (block or ""):gmatch('"([^"]+)"') do
		set[name] = true
	end
	return set, block ~= nil
end

-- Shipped files in TOC order: .lua and .xml paths relative to the repo root.
local function shippedFiles(tocText, ignores, readText)
	local files, seen = {}, {}
	local function add(path)
		path = normalize(path)
		if seen[path] or isIgnored(path, ignores) then
			return
		end
		seen[path] = true
		files[#files + 1] = path
		if path:match("%.xml$") then
			local text = readText(path)
			if text then
				for _, inc in ipairs(scanXml(text).includes) do
					add(dirOf(path) .. "/" .. inc)
				end
			end
		end
	end
	for line in (tocText .. "\n"):gmatch("([^\n]*)\n") do
		line = trim(line:gsub("\r$", ""))
		if line ~= "" and line:sub(1, 1) ~= "#" then
			add(line)
		end
	end
	return files
end

-- Runs the whole check over `files`; returns a list of { id, path, detail }.
local function check(files, readText, declared, allowed, unresolvedOk)
	local problems = {}
	local function add(id, path, detail)
		problems[#problems + 1] = { id, path, detail }
	end
	local function report(path, r, how)
		for _, hit in ipairs(r.names) do
			if not declared[hit.name] and not allowed[hit.name] then
				add("name", path, hit.how .. ' creates global "' .. hit.name .. '" (not in .luacheckrc globals or the allowlist)' .. how)
			end
		end
		for _, call in ipairs(r.unresolved) do
			if not unresolvedOk[path .. ": " .. call.key] then
				add("unresolved", path, "name cannot be resolved statically: " .. call.key .. " near line " .. call.line .. how)
			end
		end
	end
	local specialHint = " (Escape is wired with SetScript/OnKeyDown, never by inserting here)"
	for _, path in ipairs(files) do
		local text = readText(path)
		if not text then
			add("read", path, "listed in the TOC but cannot be read")
		elseif path:match("%.lua$") then
			local r = scanLua(text)
			report(path, r, "")
			for _, where in ipairs(r.special) do
				add("uispecial", path, "UISpecialFrames is mentioned at " .. where .. specialHint)
			end
		elseif path:match("%.xml$") then
			local x = scanXml(text)
			for _, hit in ipairs(x.names) do
				if not declared[hit.name] and not allowed[hit.name] then
					add("name", path, 'XML name="' .. hit.name .. '" (not in .luacheckrc globals or the allowlist)')
				end
			end
			for _, body in ipairs(x.bodies) do
				report(path, scanLua(body), " (inline script)")
			end
			if x.special then
				add("uispecial", path, "UISpecialFrames is mentioned" .. specialHint)
			end
		end
	end
	return problems
end

-- Self-check: the scanner must flag each failure shape below, or this test
-- would pass on a regression. Fixture text is in memory only.
local function selfCheck()
	local fixture = {
		["a.lua"] = table.concat({
			'local NAME = "HomesteadFixtureConst"',
			'local f = CreateFrame("Frame", "HomesteadFixtureNamed", UIParent)',
			'local g = CreateFrame("Frame",',
			"    NAME, UIParent)",
			'local ok = CreateFrame("Frame", nil, UIParent)',
			'_G.HomesteadFixtureWrite = 1',
			'_G["HomesteadFixtureIndexed"] = 2',
			'_G["Prefix" .. i] = 3',
			'tinsert(UISpecialFrames, "X")',
			'-- CreateFrame("Frame", "HomesteadFixtureInComment")',
			'local same = _G.Minimap == nil',
			'_G.HomesteadFixtureMultiA, _G.HomesteadFixtureMultiB = 1, 2',
			'print(_G.HomesteadFixtureArgA, _G.HomesteadFixtureArgB)',
			'local Layout = { PANEL = "HomesteadFixtureField" }',
			'local function make(PANEL) return CreateFrame("Frame", PANEL, UIParent) end',
			"local h = CreateFrame('Frame', 'HomesteadFixtureSingle', UIParent)",
			"local T = {",
			'    PANEL = "HomesteadFixtureField"',
			"}",
		}, "\n"),
		["b.xml"] = table.concat({
			'<Ui><!-- <Frame name="HomesteadFixtureXmlComment"/> -->',
			'<Frame name="HomesteadFixtureXml" virtual="true"/>',
			"<Frame name='HomesteadFixtureXmlSingle'/>",
			'<Frame><Scripts><OnLoad>_G.HomesteadFixtureXmlWrite = 1',
			'tinsert(UISpecialFrames, self:GetName())',
			'local x = CreateFrame("Frame", "HomesteadFixtureXmlFrame")',
			'if 1 &lt; 2 then end</OnLoad></Scripts></Frame>',
			'<Script><![CDATA[ _G.HomesteadFixtureXmlCdata = 1 ]]></Script>',
			'<!-- <Scripts><OnLoad>_G.HomesteadFixtureXmlCommented = 1</OnLoad></Scripts> -->',
			'</Ui>',
		}, "\n"),
	}
	local function read(path)
		return fixture[path]
	end
	local problems = check({ "a.lua", "b.xml" }, read, { Homestead = true }, {}, {})
	local text = {}
	for _, p in ipairs(problems) do
		text[#text + 1] = p[3]
	end
	text = table.concat(text, "\n")
	local expected = {
		'"HomesteadFixtureNamed"',
		'"HomesteadFixtureConst"',
		'"HomesteadFixtureWrite"',
		'"HomesteadFixtureIndexed"',
		'"HomesteadFixtureMultiA"',
		'"HomesteadFixtureMultiB"',
		'"HomesteadFixtureSingle"',
		'XML name="HomesteadFixtureXml"',
		'XML name="HomesteadFixtureXmlSingle"',
		'name cannot be resolved statically: _G write(',
		"UISpecialFrames is mentioned at line 9",
		-- the parameter PANEL shares its name with a table field, and must not resolve
		"name cannot be resolved statically: CreateFrame(PANEL) near line 15",
		-- inline XML scripts
		'"HomesteadFixtureXmlWrite" (not in .luacheckrc globals or the allowlist) (inline script)',
		'"HomesteadFixtureXmlFrame" (not in .luacheckrc globals or the allowlist) (inline script)',
		'"HomesteadFixtureXmlCdata"',
	}
	for _, want in ipairs(expected) do
		if not text:find(want, 1, true) then
			fail("self", "tests/globals_check.lua", "scanner missed: " .. want)
		end
	end
	local xmlSpecial = false
	for _, p in ipairs(problems) do
		xmlSpecial = xmlSpecial or (p[1] == "uispecial" and p[2] == "b.xml")
	end
	if not xmlSpecial then
		fail("self", "tests/globals_check.lua", "scanner missed: UISpecialFrames in an inline XML script")
	end
	for _, bad in ipairs({ "InComment", "XmlComment", "Minimap", "ArgA", "ArgB", "XmlCommented", "HomesteadFixtureField" }) do
		if text:find(bad, 1, true) then
			fail("self", "tests/globals_check.lua", "scanner flagged something it should skip: " .. bad)
		end
	end
	local declared = {}
	for _, name in ipairs({ "Named", "Const", "Write", "Indexed", "MultiA", "MultiB", "Single" }) do
		declared["HomesteadFixture" .. name] = true
	end
	for _, p in ipairs(check({ "a.lua" }, read, declared, {}, {})) do
		if p[1] == "name" then
			fail("self", "tests/globals_check.lua", "a declared name was still flagged: " .. p[3])
		end
	end
end

selfCheck()

local function readRoot(path)
	return readFile(root .. "/" .. path)
end

local luacheckrc = readRoot(".luacheckrc")
local pkgmeta = readRoot(".pkgmeta")
local toc = readRoot("Homestead.toc")
if not luacheckrc or not pkgmeta or not toc then
	fail("setup", root, "needs .luacheckrc, .pkgmeta and Homestead.toc (run from the repo root)")
	finish()
end

local declared, found = luacheckGlobals(luacheckrc)
if not found or next(declared) == nil then
	fail("setup", ".luacheckrc", "could not read the globals = { ... } block")
	finish()
end

local files = shippedFiles(toc, pkgmetaIgnores(pkgmeta), readRoot)
if #files < 20 then
	fail("setup", "Homestead.toc", "only " .. #files .. " shipped files found; the TOC parse is broken")
	finish()
end

for _, p in ipairs(check(files, readRoot, declared, ALLOWED_TODAY, UNRESOLVED_TODAY)) do
	fail(p[1], p[2], p[3])
end

finish()
