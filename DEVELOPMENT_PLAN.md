# Homestead Development Plan

## Current Version: 0.3.0-alpha

## Quick Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | Core Infrastructure | ✅ Complete |
| 2 | Vendor Database | ✅ Complete |
| 3 | Map Integration | ✅ Complete |
| 4 | Ownership Detection | ✅ Complete |
| 5 | Tooltip Enhancements | ✅ Complete |
| 6 | Achievement/Quest Sources | 📋 Planned |
| 7 | Endeavours Tracking | 📋 Planned |
| 8 | Main UI Browser | 📋 Planned |
| 9 | Bag/Merchant Overlays | 📋 Planned |
| 10 | Export/Import | ✅ Complete |

---

## UX Patterns

### First-Run Experience

On first load (detect via `db.global.firstRunComplete ~= true`):

**Step 1: Welcome Message**
```lua
-- In OnEnable or PLAYER_ENTERING_WORLD
if not self.db.global.firstRunComplete then
    self:Print("Welcome to Homestead!")
    self:Print("Open your Housing Catalog once to sync your collection.")
    self:Print("Then run /hs scan to cache your owned items.")
end
```

**Step 2: After First Successful Scan**
```lua
-- In CatalogScanner after scan completes with items
if ownedCount > 0 and not HA.Addon.db.global.firstRunComplete then
    HA.Addon.db.global.firstRunComplete = true
    HA.Addon:Print(string.format("|cff00ff00Synced!|r Found %d owned items.", ownedCount))
end
```

**Step 3: If Scan Returns Zero**
```lua
-- In ManualScan if checked > 0 but owned == 0
if checked > 0 and owned == 0 then
    self:Print("No owned items detected.")
    self:Print("Try opening your Housing Catalog UI first, then run /hs scan again.")
    self:Print("(This works around a Blizzard API limitation)")
end
```

### Success Feedback

Always provide positive feedback for actions:

```lua
-- After successful scan
self:Print(string.format("|cff00ff00Scan complete!|r Found %d owned items.", count))

-- After export
self:Print(string.format("|cff00ff00Exported|r %d vendors with %d items.", vendorCount, itemCount))

-- After import  
self:Print(string.format("|cff00ff00Import complete!|r %d new, %d updated.", imported, updated))
```

---

## Phase 5: Tooltip Enhancements ✅

**Goal**: Show ownership status and source info in item tooltips.

### Tasks

- [x] Hook `GameTooltip:OnTooltipSetItem` (via TooltipDataProcessor)
- [x] Add ownership line (✓ Owned / Not Owned)
- [x] Add source line ("Available from [Vendor] in [Zone]")
- [x] Add quantity info for owned items
- [x] Respect user settings for tooltip display (enabled, showOwned, showSource, showQuantity)
- [x] Handle items with multiple sources (returns first vendor)
- [x] Hook Housing Catalog tooltips via EventRegistry
- [x] Use Blizzard sourceText when available, fallback to VendorDatabase
- [x] Show vendor notes in tooltips
- [x] Add reverse index (ByItemID) for O(1) item lookups

### Implementation Notes

```lua
-- Tooltip hook pattern
GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local name, link = self:GetItem()
    if not link then return end
    
    local itemID = GetItemInfoFromHyperlink(link)
    if not itemID then return end
    
    -- Check if housing decor
    local info = C_HousingCatalog.GetCatalogEntryInfoByItem(link, true)
    if not info then return end  -- Not a decor item
    
    -- Add ownership status
    if HA.DecorTracker:IsItemOwned(itemID) then
        self:AddLine("Housing: |cff00ff00Owned|r", 1, 1, 1)
    else
        self:AddLine("Housing: |cffff0000Not Owned|r", 1, 1, 1)
        
        -- Add source info
        local vendor = HA.VendorData:GetVendorForItem(itemID)
        if vendor then
            self:AddLine(string.format("  Available: %s (%s)", vendor.name, vendor.zone), 0.7, 0.7, 0.7)
        end
    end
    
    self:Show()
end)
```

### Testing Checklist

- [x] Tooltip shows on vendor items
- [x] Tooltip shows on bag items
- [x] Tooltip shows on auction house items
- [x] Owned items show correctly
- [x] Unowned items show vendor source
- [x] Performance acceptable (O(1) lookups via ByItemID index)

### Debug Commands

- `/hs testlookup <itemID>` - Test VendorDatabase item lookup
- `/hs testsource [itemID]` - Test C_HousingCatalog API sourceText

---

## Phase 6: Achievement/Quest Sources

**Goal**: Expand item coverage beyond vendors.

### Data Sources to Add

| Source | Priority | Effort | Coverage |
|--------|----------|--------|----------|
| Achievements | High | Medium | ~200 items |
| Quests | High | Medium | ~100 items |
| Reputation Rewards | Medium | Low | ~50 items |
| World Drops | Low | High | Unknown |
| Crafted | Low | High | ~100 items |

### Tasks

- [ ] Create `Data/AchievementDecor.lua` with achievement → itemID mapping
- [ ] Create `Data/QuestDecor.lua` with quest → itemID mapping
- [ ] Create `Data/ReputationDecor.lua` with rep → itemID mapping
- [ ] Create `DecorDatabase.lua` unified access layer
- [ ] Update tooltip to show non-vendor sources
- [ ] Update ownership scanner to check all sources

### Data Structure

```lua
-- Data/AchievementDecor.lua
HA.AchievementDecor = {
    [achievementID] = {
        name = "Achievement Name",
        items = {
            {itemID = 123456, name = "Item Name"},
        },
        category = "Quests"|"Exploration"|"PvP"|etc,
    },
}

-- Data/QuestDecor.lua  
HA.QuestDecor = {
    [questID] = {
        name = "Quest Name",
        itemID = 123456,
        mapID = 2339,
        faction = "Alliance"|"Horde"|"Neutral",
    },
}
```

### Sources for Data

- Home Bound addon (achievement mapping - cross-reference, don't copy)
- Wowhead achievement rewards pages
- In-game achievement UI scanning
- Housing Reps addon (reputation rewards)

---

## Phase 7: Endeavours Tracking

**Goal**: Track Housing Endeavours (daily/weekly tasks) and rewards.

### Features

- [ ] Display active Endeavour tasks
- [ ] Show progress on each task
- [ ] Track Favor currency earned
- [ ] Show available rewards at current Favor level
- [ ] Notify when tasks are complete
- [ ] Track house level progress

### API Research Needed

```lua
-- Potential APIs to investigate
C_Housing*          -- Housing-related APIs
C_TaskQuest*        -- Daily/weekly task system
C_QuestLog*         -- Quest progress
C_CurrencyInfo*     -- Favor currency tracking
```

### UI Concept

Compact panel showing:
```
┌─────────────────────────────────┐
│ Housing Endeavours              │
├─────────────────────────────────┤
│ Daily Tasks (2/3 Complete)      │
│ ✓ Place 5 decorations           │
│ ✓ Visit a neighbor              │
│ ○ Harvest crops (2/5)    [====--] │
├─────────────────────────────────┤
│ Weekly Tasks (0/1 Complete)     │
│ ○ Complete 5 dailies (3/5) [===--] │
├─────────────────────────────────┤
│ Favor: 1,250 | House Level: 3   │
└─────────────────────────────────┘
```

---

## Phase 8: Main UI Browser

**Goal**: Dedicated window for browsing collection and vendors.

### Features

- [ ] Tabbed interface: Collection | Vendors | Sources
- [ ] Collection tab: Grid of owned/missing items with filters
- [ ] Vendors tab: List of vendors with search, filter by zone/faction
- [ ] Sources tab: Progress by source type (vendors, achievements, quests)
- [ ] Click vendor to set TomTom waypoint
- [ ] Right-click item to view in dressing room
- [ ] Filter: Owned/Missing, Expansion, Zone, Faction

### UI Framework

- Use Ace3 AceGUI for consistent styling
- Or custom frames with modern WoW 11.x styling
- Target: 800x600 resizable window

### Mock-up Reference

See `UI_MOCKUP.jsx` for visual design.

---

## Phase 9: Bag/Merchant Overlays

**Goal**: Visual indicators on items in bags and merchant windows.

### Overlay Icons

| Icon | Meaning |
|------|---------|
| ✓ Green check | Already owned |
| 🏠 House | Housing decor item (not owned) |
| Number badge | Quantity owned |

### Tasks

- [ ] Create overlay frame pool
- [ ] Hook container frame updates
- [ ] Hook merchant frame updates
- [ ] Position icons in corner of item slots
- [ ] Handle icon cleanup on container close
- [ ] Add toggle in settings

---

## Phase 10: Export/Import ✅

**Status**: Complete

### Implemented Features

- [x] `/hs export` - Export scanned vendor data to copyable string
- [x] `/hs import` - Import vendor data from community
- [x] Version-tagged format (HOMESTEAD_EXPORT_V1)
- [x] Deduplication and newer-data-wins logic
- [x] Auto-refresh map pins after import

### Files

- `Modules/ExportImport.lua`

---

## Backlog / Ideas

- TomTom integration for vendor waypoints
- TSM/Auctionator price integration
- 3D model preview in tooltips
- Crafting material tracker
- Neighborhood visiting tracker
- Housing screenshot manager

---

## Technical Debt

- [x] Add data validation for vendor database (`/hs validate`)
- [ ] Create merge script for scanner exports
- [ ] Add version migration system for SavedVariables
- [ ] Improve error handling in API calls
- [ ] Add unit tests for core functions

---

## Release Checklist

Before each release:

- [ ] Update version in TOC
- [ ] Update CHANGELOG.md
- [ ] Test on fresh character (no SavedVariables)
- [ ] Test after `/reload`
- [ ] Test with debug mode on/off
- [ ] Package without development files
- [ ] Tag release in git
