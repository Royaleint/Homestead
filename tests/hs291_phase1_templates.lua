-- luacheck: globals assert io print

local function read(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local export = read("Modules/ExportImport.lua")
assert(export:find('CreateFrame%("Frame", "HomesteadExportDialog", UIParent, "DefaultPanelTemplate"%)'),
    "export dialog must use DefaultPanelTemplate")
assert(not export:find("SetBackdrop"), "export dialog must not retain hand-rolled backdrop setup")
assert(export:find("f.TitleContainer.TitleText:SetText"), "export dialog must use the native title")

local options = read("UI/OptionsFrame.lua")
assert(options:find('CreateFrame%("Button", nil, parent, "PanelTabButtonTemplate"%)'),
    "options navigation must use PanelTabButtonTemplate")
assert(options:find("PanelTemplates_SelectTab%(button%)"),
    "options navigation must drive native selected state")
assert(not options:find("button.selectedTexture ="),
    "options navigation must not recreate the removed selected texture")

local sidePanel = read("UI/MapSidePanel.lua")
assert(sidePanel:find('CreateFrame%("EditBox", nil, searchBar, "SearchBoxTemplate"%)'),
    "map side-panel search must use SearchBoxTemplate")
assert(sidePanel:find("FPU.AcquirePooledFrame%(iconPool, \"default\""),
    "map side-panel icons must use the shared frame-pool helper")
assert(sidePanel:find("FPU.ReleasePooledFrame%(iconPool, icon%)"),
    "map side-panel icons must release through the shared frame-pool helper")
assert(not sidePanel:find("local placeholder = searchBar:CreateFontString"),
    "map side-panel search must not retain a hand-rolled placeholder")

print("hs291_phase1_templates: ok")
