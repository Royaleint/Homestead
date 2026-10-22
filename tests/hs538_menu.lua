-- luacheck: globals assert
-- Shared dropdown stub for the browser tests. Running this file alone does nothing; the tests load it:
--   local menuStub = assert(loadfile(root .. "/tests/hs538_menu.lua"))()
--   menuStub(widget, template)
-- It gives a widget built from WowStyle1DropdownTemplate or WowStyle1FilterDropdownTemplate the menu
-- behaviour of Blizzard_Menu, in the same order, so a menu callback that reads state too early fails here:
--   SetupMenu stores the generator and, if the button is shown (its own flag, not visibility), generates.
--   GenerateMenu runs the generator into a fresh root, then walks every element and calls each radio's and
--   checkbox's isSelected(data); the selection-text template sets its text from the selected elements
--   through its translator (element text until one is set).
--   The selection-text template also generates on OnShow; the filter template does not.
--   TestPick(text) runs that element's responder as a click does, then walks the selections again.
-- The generator stays in widget.menu, so a test can still read the menu's items directly.

local function NewRoot()
    local root = { items = {} }
    local function Add(e)
        root.items[#root.items + 1] = e
        return e
    end
    function root:CreateCheckbox(text, isSel, setSel, data)
        return Add({ text = text, isSel = isSel, setSel = setSel, data = data, selectable = true })
    end
    function root:CreateRadio(text, isSel, setSel, data)
        return Add({ text = text, isSel = isSel, setSel = setSel, data = data, selectable = true })
    end
    function root:CreateButton(text, click, data) return Add({ text = text, click = click, data = data }) end
    function root:CreateDivider() return Add({ divider = true }) end
    function root:CreateTitle(text) return Add({ text = text }) end
    return root
end

return function(w, template)
    local selectionText = template == "WowStyle1DropdownTemplate"
    assert(selectionText or template == "WowStyle1FilterDropdownTemplate", "not a dropdown template: " .. tostring(template))

    local function Selections(self)
        local out = {}
        for _, e in ipairs(self.menuDescription and self.menuDescription.items or {}) do
            if e.selectable and e.isSel(e.data) then out[#out + 1] = e end
        end
        return out
    end

    function w:SignalUpdate()
        local selected = Selections(self)
        self.generated = (self.generated or 0) + 1
        if selectionText then
            local texts = {}
            for i, e in ipairs(selected) do texts[i] = self.selectionTranslator(e) end
            self.text = #texts > 0 and table.concat(texts, ", ") or self.defaultText
        else
            -- DropdownTextMixin:UpdateText: the fixed text again, resized only if resizeToText is on.
            self:SetText(self.text)
        end
    end

    function w:SetupMenu(fn)
        assert(type(fn) == "function", "SetupMenu(generator): argument is not a function")
        self.menu = fn
        if self.shown then self:GenerateMenu() end
    end

    function w:GenerateMenu()
        if not self.menu then return end
        local root = NewRoot()
        self.menu(self, root)
        self.menuDescription = root
        self:SignalUpdate()
    end

    function w:TestPick(text)
        for _, e in ipairs(self.menuDescription and self.menuDescription.items or {}) do
            if e.text == text then
                if e.setSel then e.setSel(e.data) elseif e.click then e.click(e.data) end
                self:SignalUpdate()
                return e
            end
        end
        error("no menu element " .. tostring(text))
    end

    if selectionText then
        w.selectionTranslator = function(e) return e.text end
        function w:SetSelectionTranslator(fn) self.selectionTranslator = fn end
        w.scripts = w.scripts or {}
        w.scripts.OnShow = function(self) self:GenerateMenu() end
    end
    return w
end
