-- luacheck: globals assert loadfile print
-- Run from the repo root:  lua tests/hs538_first_open.lua [root]

local root = (... or "."):gsub("\\", "/"):gsub("/+$", "")
local newWorld = assert(loadfile(root .. "/tests/hs538_world.lua"))()

-------------------------------------------------------------------------------
-- The first open as a player makes it: B:Toggle with no saved state builds the
-- real window, the real router and every real tab, then each tab is opened in
-- turn from its tree row (Overview, Catalog, Vendors), then an item page from a
-- Summary row and from a Catalog row, then a close and a reopen. Frames that
-- become visible run their OnShow and the dropdowns build their menus the way
-- the client does, so any callback that reads state before it exists fails here.
-------------------------------------------------------------------------------

local function eq(a, b, msg)
    if a ~= b then error((msg or "mismatch") .. ": got " .. tostring(a) .. ", wanted " .. tostring(b), 2) end
end

local env = newWorld(root, { realWindow = true })
-- No saved browser state: no position, the tip not yet seen, Hide off.
env.HA.Addon.db.profile.browser = {}
env.standard()
local B = env.B
local Win = B.Window

-- What the minimap button and the key binding call.
B:Toggle()
assert(Win.frame and Win.frame:IsVisible(), "the first Toggle opens the window")
eq(Win.frame.template, "ButtonFrameTemplate", "the real window is built")
env.open()
eq(env.tab, "summary", "the first open shows Summary")
assert(env.pages[1]:IsVisible(), "the Summary page is visible")
env.flush()
print("hs538_first_open: Toggle to Summary ok")

-- Clicks the tree row with this label, as drawn.
local function clickNav(label)
    for _, box in ipairs(env.boxList) do
        for _, f in ipairs(box.frames) do
            if f.data and f.data.label == label then return f.scripts.OnClick(f) end
        end
    end
    error("no tree row " .. label)
end

local sort
for _, f in ipairs(env.all) do
    if f.template == "WowStyle1DropdownTemplate" then sort = f end
end
local built = sort.generated
clickNav("Catalog")
eq(env.tab, "catalog", "the Catalog tree row shows Catalog")
assert(env.pages[2]:IsVisible() and not env.pages[1]:IsVisible(), "only the Catalog page is visible")
-- A tree row opens the page with a fresh view: the show rebuilds the menu, and so does the reset.
eq(sort.generated, built + 2, "the sort button rebuilt its menu when its page was shown and the view reset")
eq(sort.text, "Sort: Best to get now", "the sort label")
assert(#(env.catalogList()) > 0, "the Catalog lists decor")
env.flush()
print("hs538_first_open: Catalog ok")

clickNav("Vendors")
eq(env.tab, "sources", "the Vendors tree row shows the vendors list")
assert(#(env.sourcesList()) > 0, "Sources lists vendors")
env.flush()
print("hs538_first_open: Sources ok")

-- The header search: one box with the Overview's placeholder; a tree row clears it, Enter lands on All decor.
local search = Win.search
assert(search and search:IsVisible(), "the header has a search box")
eq(search.Instructions.text, "Search decor", "the header box placeholder")
search.text = "stale"
clickNav("Overview")
eq(search.text, "", "a tree row opens its page with an empty search box")
search.text = " elm "
search.scripts.OnEnterPressed(search)
eq(env.tab, "catalog", "Enter on the Overview searches the Catalog")
eq(env.idString(), "2", "the Catalog lists Elm Chair only")
eq(search.text, "elm", "the header box keeps the words")
env.flush()
print("hs538_first_open: header search ok")

-- An item page from Summary: the row's Show button lands on the Catalog with the item selected.
clickNav("Overview")
local row
for _, f in ipairs(env.all) do
    if env.owner(f) == "summary" and rawget(f, "why") and f.itemID and f.shown then row = row or f end
end
assert(row, "Summary draws a row")
env.click(row)
eq(env.tab, "catalog", "a Summary row opens the Catalog")
eq(env.selectedItem(), row.itemID, "with its item page")
-- And from a Catalog row.
local other = env.catalogRow(2)
assert(other, "the Catalog draws Elm Chair")
other.d.onClick()
eq(env.selectedItem(), 2, "a Catalog row opens its item page")
env.flush()
print("hs538_first_open: item page ok")

-- Close and open again: the window keeps its frames and opens on Summary.
B:Toggle()
eq(Win.closing, true, "the second Toggle starts the close fade")
-- What the fade's OnFinished does; the window's OnHide runs.
Win.frame:Hide()
assert(not Win.frame:IsVisible(), "the second Toggle closes the window")
eq(Win.closing, false, "the window's OnHide ran")
B:Toggle()
assert(Win.frame:IsVisible(), "the third Toggle opens it again")
eq(env.tab, "summary", "a reopen shows Summary")
clickNav("Catalog")
eq(env.tab, "catalog", "and the Catalog again")
env.flush()
print("hs538_first_open: close and reopen ok")
print("hs538_first_open: ok")
