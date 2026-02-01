# WoW Addon Development Skill

> **Installation**: Place this folder at `~/.claude/skills/wow-addon/`  
> This skill is reusable across all WoW addon projects.

---

## When to Use

Use this skill when:
- Writing or debugging WoW addon Lua code
- Working with Ace3 framework
- Handling WoW events
- Creating UI frames
- Hooking Blizzard UI elements

---

## Ace3 Framework

### Addon Creation
```lua
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0", "AceEvent-3.0")

function MyAddon:OnInitialize()
    -- Runs once at ADDON_LOADED
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", defaults, true)
end

function MyAddon:OnEnable()
    -- Runs when addon enabled, register events here
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end
```

### AceDB Defaults
```lua
local defaults = {
    global = {}, -- Cross-character
    profile = {  -- Per-profile (usually per-character)
        enabled = true,
    },
}
```

---

## Event Handling

### WoW Events (Correct Pattern)
```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("BAG_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "MERCHANT_SHOW" then
        -- Handle
    elseif event == "BAG_UPDATE" then
        local bagID = ...
    end
end)
```

### Common Mistakes
```lua
-- WRONG: Don't register events inside OnEvent
frame:SetScript("OnEvent", function(self, event)
    self:RegisterEvent("OTHER")  -- Causes issues
end)

-- WRONG: Don't cache APIs at load time
local GetItemInfo = GetItemInfo  -- May be nil

-- CORRECT: Access at runtime
local name = _G.GetItemInfo(itemID)
```

---

## Timing

```lua
-- Next frame
C_Timer.After(0, function() end)

-- Delayed
C_Timer.After(0.5, function() end)

-- Repeating
local ticker = C_Timer.NewTicker(1.0, function() end)
ticker:Cancel()  -- Stop it
```

---

## Frame Creation

```lua
-- Basic frame
local f = CreateFrame("Frame", "MyFrame", UIParent)
f:SetSize(200, 100)
f:SetPoint("CENTER")

-- With backdrop (9.0+)
local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = {left=4, right=4, top=4, bottom=4},
})

-- Button
local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
btn:SetText("Click")
btn:SetScript("OnClick", function(self, button) end)
```

### Frame Strata (back to front)
```
BACKGROUND < LOW < MEDIUM < HIGH < DIALOG < FULLSCREEN < FULLSCREEN_DIALOG < TOOLTIP
```

### Texture Layers (within frame)
```
BACKGROUND < BORDER < ARTWORK < OVERLAY < HIGHLIGHT
```

---

## Anchoring

```lua
frame:SetPoint("CENTER")                    -- Center of parent
frame:SetPoint("TOPLEFT", 10, -10)          -- Offset from parent
frame:SetPoint("LEFT", other, "RIGHT", 5, 0) -- Relative to other frame
frame:ClearAllPoints()                       -- Reset before re-anchoring
```

---

## Tooltip Hooking

```lua
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local name, link = self:GetItem()
    if link then
        self:AddLine("My custom line", 0, 1, 0)
        self:Show()
    end
end)
```

---

## Safe Hooking

```lua
-- Won't taint secure frames
hooksecurefunc("BlizzardFunction", function(...)
    -- Runs AFTER original
end)

-- Check combat lockdown
if InCombatLockdown() then return end
```

---

## Common APIs

```lua
-- Item
local name, link, quality = GetItemInfo(itemID)

-- Unit
local name = UnitName("target")
local guid = UnitGUID("target")

-- Map
local mapID = C_Map.GetBestMapForUnit("player")
local pos = C_Map.GetPlayerMapPosition(mapID, "player")
local x, y = pos:GetXY()  -- 0-1 normalized
```

---

## Slash Commands

```lua
SLASH_MYADDON1 = "/myaddon"
SlashCmdList["MYADDON"] = function(msg)
    local cmd = strsplit(" ", msg)
    if cmd == "debug" then
        -- toggle debug
    end
end
```

---

## Performance

1. Cache in locals: `local pairs = pairs`
2. Reuse tables: `wipe(t)` instead of `t = {}`
3. Throttle OnUpdate to 10fps max
4. Use C_Timer over OnUpdate when possible
5. Use frame pools for dynamic UI elements
