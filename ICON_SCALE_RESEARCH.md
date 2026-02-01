# VendorMapPins Icon Scale Research

## Problem
Icons appeared too large on world map despite setting small frame/texture sizes (12px base).
Changing sizes had NO visible effect - icons stayed the same size.

## Root Cause (when using HereBeDragons)
We were using HereBeDragons-Pins-2.0 which:
1. Creates its own 1x1 pin frame with `SetScalingLimits(1, 1.0, 1.2)` (line 464)
2. Takes OUR frame and parents it to the 1x1 pin (line 472: `icon:SetParent(self)`)
3. Centers our frame on the pin (line 474: `icon:SetPoint("CENTER", self, "CENTER")`)

The problem: Our frame sizes were being ignored because the WorldMapFrame canvas
applies a large scale factor. Our 12px frame became huge on screen.

## Why Size Changes Didn't Work
- We set `frame:SetSize(12, 12)`
- Frame is parented to HBD's pin, which is parented to canvas
- Canvas has a scale like 3-5x applied
- Our 12px becomes 36-60px on screen
- Changing to 10px or 14px makes minimal visual difference

## HandyNotes Does NOT Use HereBeDragons for World Map
Key insight: HandyNotes creates its OWN `MapCanvasPinMixin` pins:
```lua
local size = 12 * db.icon_scale * scale
self:SetSize(size, size)  -- 'self' is the PIN, not a child frame
```

HandyNotes registers its own data provider and pin template with WorldMapFrame,
bypassing HereBeDragons entirely for world map pins. HereBeDragons is primarily
designed for MINIMAP pins where this scaling issue doesn't exist.

## Solution Implemented

We created our own native pin system following the HandyNotes pattern:

### HomesteadVendorPinMixin (inherits from MapCanvasPinMixin)
```lua
HomesteadVendorPinMixin = CreateFromMixins(MapCanvasPinMixin)

function HomesteadVendorPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 0.75, 1.5)  -- scaleFactor, startScale, endScale
end

function HomesteadVendorPinMixin:OnAcquired(pinType, pinData, x, y)
    self.pinType = pinType
    self.pinData = pinData
    self:SetPosition(x, y)

    local size = 20
    self:SetSize(size, size)  -- Size on the PIN itself, not a child frame

    self:SetupVisuals()
end
```

### HomesteadVendorDataProvider (inherits from MapCanvasDataProviderMixin)
```lua
HomesteadVendorDataProvider = CreateFromMixins(MapCanvasDataProviderMixin)

function HomesteadVendorDataProvider:RefreshAllData(fromOnShow)
    self:RemoveAllData()
    -- Show pins based on map type (zone, continent, world)
end
```

### Pin Template Registration
```lua
local function CreatePinTemplate()
    local pinTemplate = "HomesteadVendorPinTemplate"

    local function pinCreationFunc(framePool)
        local frame = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
        frame:SetSize(20, 20)
        frame:EnableMouse(true)
        Mixin(frame, HomesteadVendorPinMixin)
        frame:OnLoad()
        return frame
    end

    local pool = CreateFramePool("FRAME", WorldMapFrame:GetCanvas(), nil, pinResetFunc, false, pinCreationFunc)
    WorldMapFrame.pinPools[pinTemplate] = pool
end
```

## Key Differences from HereBeDragons Approach

| Aspect | HereBeDragons | Native Implementation |
|--------|---------------|----------------------|
| Pin ownership | HBD creates pins, we provide child frames | We create and own the pins directly |
| Size control | Size on child frame (ignored by canvas scale) | Size on pin itself (properly handled) |
| Scaling | HBD's SetScalingLimits on wrapper | Our SetScalingLimits on actual pin |
| Data provider | HBD internal provider | Our custom provider |

## Alternative Solutions Considered

### Option 1: Use frame:SetScale() to Counter Canvas Scale
```lua
frame:SetScale(0.4)  -- Counter the canvas scale
```
This was a workaround, not a proper fix.

### Option 2: Use Only Textures (No Frame)
Pass a single Texture to HBD instead of a Frame.
Untested, may have had similar issues.

## References
- [Region:SetScale](https://wowpedia.fandom.com/wiki/API_Region_SetScale)
- [HandyNotes.lua](https://github.com/Nevcairiel/HandyNotes/blob/master/HandyNotes.lua)
- [HandyNotes.xml](https://github.com/Nevcairiel/HandyNotes/blob/master/HandyNotes.xml)
- HereBeDragons-Pins-2.0.lua lines 351-475 (pin creation and icon attachment)
