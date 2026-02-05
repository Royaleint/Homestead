# WoW Housing API Reference

Generated from Townlong Yak FrameXML documentation
Source: townlong-yak.com/framexml/live

---

## HousingDecorSharedDocumentation (from HousingDecorSharedDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Enumerations

#### HousingDecorPlacementRestriction
| Name | Value | Documentation |
|------|-------|---------------|
| TooFarAway | 1 |  |
| OutsideRoomBounds | 2 |  |
| OutsidePlotBounds | 4 |  |
| ChildOutsideBounds | 8 |  |
| InvalidTarget | 16 |  |
| InvalidCollision | 32 |  |

### Structures

#### HousingDecorDyeSlot
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| ID | number | No |  |
| dyeColorCategoryID | number | No | What category of dye colors this slot is for; This currently has no functional useage as slots accept colors of any category, but may be used for things like labeling in the future |
| orderIndex | number | No | Display sort order |
| channel | number | No | The specific shader channel that this slot affects when a dye color is applied |
| dyeColorID | number | Yes | What dye color (if any) is currently applied to this slot |

#### HousingDecorInstanceInfo
*Info for an instance of Housing Decor that has been/is being placed within a House or its exterior Plot*

| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| decorGUID | WOWGUID | No |  |
| decorID | number | No |  |
| name | cstring | No |  |
| isLocked | bool | No | True if this decor is already being edited by someone else |
| canBeCustomized | bool | No | True if this decor can be customized, namely by applying Dyes |
| canBeRemoved | bool | No | False if this decor must remain placed in the house and cannot be placed back into house chest storage |
| isAllowedOutdoors | bool | No |  |
| isAllowedIndoors | bool | No |  |
| isRefundable | bool | No |  |
| dyeSlots | table<HousingDecorDyeSlot> | No | Empty for decor that can't be dyed (see canBeCustomized) |
| dataTagsByID | LuaValueVariant | No | Simple localized 'tag' strings that are primarily used for things like categorization and filtering |
| size | HousingCatalogEntrySize | No |  |

---
## HousingCatalogUI (from HousingCatalogUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingCatalog
- **Environment**: All

### Functions

#### CanDestroyEntry
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Returns false if the entry can't be deleted from storage; Typically these types of entries are something that doesn't count towards the max storage limit"
- **Args**: entryID (HousingCatalogEntryID)
- **Returns**: canDelete (bool)

#### CreateCatalogSearcher
- **Tainted**: No
- **Doc**: "Creates a new instance of a HousingCatalog searcher; This can be used to asynchronously search/filter the HousingCatalog without affecting/being restricted by the filter state of other Housing Catalog UI displays"
- **Returns**: searcher (HousingCatalogSearcher)

#### DeletePreviewCartDecor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorGUID (WOWGUID)

#### DestroyEntry
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to delete the entry from storage"
- **Args**: entryID (HousingCatalogEntryID), destroyAll (bool) — If true, deletes all entries within the stack; If false, will only delete one

#### GetAllFilterTagGroups
- **Tainted**: No
- **Returns**: filterTagGroups (table<HousingCatalogFilterTagGroupInfo>)

#### GetBundleInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: bundleCatalogShopProductID (number)
- **Returns**: bundleInfo (HousingBundleInfo, nilable)

#### GetCartSizeLimit
- **Tainted**: No
- **Returns**: cartSizeLimit (number)

#### GetCatalogCategoryInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: categoryID (number)
- **Returns**: info (HousingCatalogCategoryInfo, nilable)

#### GetCatalogEntryInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: entryID (HousingCatalogEntryID)
- **Returns**: info (HousingCatalogEntryInfo, nilable)

#### GetCatalogEntryInfoByItem
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: itemInfo (ItemInfo) — ItemID, name, or link of an item that grants/corresponds to a particular type of housing catalog object (ex: decor), tryGetOwnedInfo (bool) — If true and player owns this entry, will return an 'Owned' subtype, with owned quantity info; Otherwise, will be an Unowned subtype with only basic static info
- **Returns**: info (HousingCatalogEntryInfo, nilable)

#### GetCatalogEntryInfoByRecordID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: entryType (HousingCatalogEntryType), recordID (number), tryGetOwnedInfo (bool) — If true and player owns this entry, will return an 'Owned' subtype, with owned quantity info; Otherwise, will be an Unowned subtype with only basic static info
- **Returns**: info (HousingCatalogEntryInfo, nilable)

#### GetCatalogEntryRefundTimeStampByRecordID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: entryType (HousingCatalogEntryType), recordID (number)
- **Returns**: refundTimeStamp (time_t, nilable)

#### GetCatalogSubcategoryInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: subcategoryID (number)
- **Returns**: info (HousingCatalogSubcategoryInfo, nilable)

#### GetDecorMaxOwnedCount
- **Tainted**: No
- **Doc**: "Returns the maximum total number of decor that can be in storage/in the house chest; Note that not all decor entries in storage count towards this limit (see GetDecorTotalOwnedCount)"
- **Returns**: maxOwnedCount (number)

#### GetDecorTotalOwnedCount
- **Tainted**: No
- **Returns**: totalOwnedCount (number) — The total number of owned decor in storage, including both exempt and non-exempt decor, exemptDecorCount (number) — The number of decor that do not count against the max storage limit

#### GetFeaturedBundles
- **Tainted**: No
- **Returns**: bundleInfos (table<HousingBundleInfo>)

#### GetFeaturedDecor
- **Tainted**: No
- **Returns**: entryInfos (table<HousingFeaturedDecorEntry>)

#### HasFeaturedEntries
- **Tainted**: No
- **Returns**: hasEntries (bool)

#### IsPreviewCartItemShown
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorGUID (WOWGUID)
- **Returns**: isShown (bool)

#### PromotePreviewDecor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorID (number), previewDecorGUID (WOWGUID)
- **Returns**: success (bool)

#### RequestHousingMarketInfoRefresh
- **Tainted**: No

#### RequestHousingMarketRefundInfo
- **Tainted**: No

#### SearchCatalogCategories
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: searchParams (HousingCategorySearchInfo)
- **Returns**: categoryIDs (table<number>)

#### SearchCatalogSubcategories
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: searchParams (HousingCategorySearchInfo)
- **Returns**: subcategoryIDs (table<number>)

#### SetPreviewCartItemShown
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorGUID (WOWGUID), shown (bool)

### Structures

#### HousingBundleDecorEntryInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| decorID | number | No |  |
| quantity | number | No |  |

#### HousingBundleInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| price | number | No |  |
| originalPrice | number | Yes |  |
| productID | number | No |  |
| decorEntries | table<HousingBundleDecorEntryInfo> | No |  |
| canPreview | bool | No | Default: True. Bundles containing non-decor items cannot be previewed |

#### HousingCatalogCategoryInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| ID | number | No |  |
| orderIndex | number | No |  |
| name | cstring | Yes |  |
| icon | textureAtlas | Yes |  |
| subcategoryIDs | table<number> | No |  |
| anyOwnedEntries | bool | No | True if the player owns anything that falls under this category |

#### HousingCatalogEntryInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| entryID | HousingCatalogEntryID | No |  |
| itemID | number | Yes |  |
| name | cstring | No |  |
| asset | ModelAsset | Yes | 3D model asset for displaying in the UI; May be nil if the entry doesn't have a model, or has one that isn't supported by UI model scenes |
| iconTexture | FileAsset | Yes | Entry icon in the form of a texture file; Catalog entries should have either this OR an iconAtlas set |
| iconAtlas | textureAtlas | Yes | Entry icon in the form a texture atlas element; Catalog entries should have either this OR an iconTexture set |
| uiModelSceneID | number | Yes | Specific UI model scene ID to use when previewing this entry's 3D model; If not set, the default catalog model scene is used |
| categoryIDs | table<number> | No |  |
| subcategoryIDs | table<number> | No |  |
| dataTagsByID | LuaValueVariant | No | Simple localized 'tag' strings that are primarily used for things like categorization and filtering |
| size | HousingCatalogEntrySize | No |  |
| placementCost | number | No | How much of the applicable budget placing this entry would cost (if any) |
| showQuantity | bool | No | Typically false if quantity isn't used by or meaningful for this particular kind of catalog entry |
| quantity | number | No | The number of fully instantiated instances of this entry that exist in storage; Does not include unredeemed instances (see remainingRedeemable) |
| remainingRedeemable | number | No | The number of unredeemed instances of this entry that exist in storage; Some auto-awarded housing objects are granted in this 'lazily-instantiated' way, and will be 'redeemed' on first being placed |
| numPlaced | number | No | The total number of instances of this entry that have been placed across all of the player's houses and plots |
| isUniqueTrophy | bool | No | This decor is flagged to display as a unique trophy item. |
| isAllowedOutdoors | bool | No | True if this entry is something that is allowed to be placed outside, within a plot |
| isAllowedIndoors | bool | No | True if this entry is something that is allowed to be placed indoors, within a house interior |
| canCustomize | bool | No | True if this entry is something that can be customized; Kinds of customization vary depending on the entry type |
| isPrefab | bool | No |  |
| quality | ItemQuality | Yes |  |
| customizations | table<cstring> | No | Labels for each of the customizations applied to this entry, if any |
| dyeIDs | table<number> | No |  |
| marketInfo | HousingMarketInfo | Yes |  |
| firstAcquisitionBonus | number | No | House XP that can be gained upon acquiring this entry for the first time |
| sourceText | cstring | No | Describes specific sources this entry may be gained from; Faction-specific sources may or may not be included based on the current player's faction |

#### HousingCatalogSubcategoryInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| ID | number | No |  |
| orderIndex | number | No |  |
| parentCategoryID | number | No |  |
| name | cstring | Yes |  |
| icon | textureAtlas | Yes |  |
| anyOwnedEntries | bool | No | True if the player owns anything that falls under this subcategory |

#### HousingCategorySearchInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| withOwnedEntriesOnly | bool | No | Default: False. If true, search will only return categories/subcategories that the player owns something under |
| includeFeaturedCategory | bool | No | Default: False.  |
| editorModeContext | HouseEditorMode | Yes | If set, will restrict results to only categories associated with/used by this Editor Mode |

#### HousingFeaturedDecorEntry
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| entryID | HousingCatalogEntryID | No |  |
| productID | number | No |  |

#### HousingMarketInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| price | number | No |  |
| productID | number | No |  |
| bundleIDs | table<number> | No |  |

#### HousingPreviewItemData
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| decorGUID | WOWGUID | Yes |  |
| productID | number | Yes |  |
| bundleCatalogShopProductID | number | Yes |  |
| isBundleParent | bool | No |  |
| isBundleChild | bool | No |  |
| id | number | No |  |
| decorID | number | No |  |
| name | string | No |  |
| icon | number | No |  |
| price | number | No |  |
| salePrice | number | Yes |  |

### Events

#### HOUSING_CATALOG_CATEGORY_UPDATED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| categoryID | number | No |

#### HOUSING_CATALOG_SUBCATEGORY_UPDATED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| subcategoryID | number | No |

#### HOUSING_DECOR_ADD_TO_PREVIEW_LIST
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| previewItemData | HousingPreviewItemData | No |

#### HOUSING_DECOR_PREVIEW_LIST_REMOVE_FROM_WORLD
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| decorGUID | WOWGUID | No |

#### HOUSING_DECOR_PREVIEW_LIST_UPDATED
*SynchronousEvent*

#### HOUSING_REFUND_LIST_UPDATED
*SynchronousEvent*

#### HOUSING_STORAGE_ENTRY_UPDATED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| entryID | HousingCatalogEntryID | No |

#### HOUSING_STORAGE_UPDATED
*UniqueEvent*

---
## HousingDecorUI (from HousingDecorUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingDecor
- **Environment**: All

### Functions

#### CancelActiveEditing
- **Tainted**: No
- **Doc**: "Cancels all in-progress editing of the selected target, which will reset any unsaved changes and deselect the active target"

#### CommitDecorMovement
- **Tainted**: No
- **Doc**: "Attempt to save the changes made to the currently selected decor instance"

#### EnterPreviewState
- **Tainted**: No

#### ExitPreviewState
- **Tainted**: No

#### GetAllPlacedDecor
- **Tainted**: No
- **Doc**: "Placed Decor List APIs currently restricted due to being potentially very expensive operations, may be reworked & opened up in the future"
- **Returns**: placedDecor (table<HousingDecorInstanceListEntry>)

#### GetDecorIcon
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorID (number)
- **Returns**: icon (fileID)

#### GetDecorInstanceInfoForGUID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Returns info for the placed decor instance associated with the passed Decor GUID, if there is one"
- **Args**: decorGUID (WOWGUID)
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetDecorName
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorID (number)
- **Returns**: name (string)

#### GetHoveredDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the placed decor instance currently being hovered, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetMaxPlacementBudget
- **Tainted**: No
- **Doc**: "Returns the max decor placement budget for the current house interior or plot; Can be increased via house level"
- **Returns**: maxBudget (number)

#### GetNumDecorPlaced
- **Tainted**: No
- **Doc**: "Returns the number of individual decor objects placed in the current house or plot; This is NOT the value used in placement budget calculations, see GetSpentPlacementBudget for that"
- **Returns**: numPlaced (number)

#### GetNumPreviewDecor
- **Tainted**: No
- **Returns**: numDecor (number)

#### GetSelectedDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the placed decor instance that's currently selected, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetSpentPlacementBudget
- **Tainted**: No
- **Doc**: "Returns how much of the current house interior or plot's decor placement budget has been spent; Different kinds of decor take up different budget amounts, so this value isn't an individual decor count, see GetNumDecorPlaced for that"
- **Returns**: totalCost (number)

#### HasMaxPlacementBudget
- **Tainted**: No
- **Doc**: "Returns whether there's a max decor placement budget available and active for the current player, in the current house interior or plot"
- **Returns**: hasMaxBudget (bool)

#### IsDecorSelected
- **Tainted**: No
- **Doc**: "Returns true if a placed decor instance is currently selected"
- **Returns**: hasSelectedDecor (bool)

#### IsGridVisible
- **Tainted**: No
- **Returns**: gridVisible (bool)

#### IsHouseExteriorDoorHovered
- **Tainted**: No
- **Doc**: "Returns true if the entry door of the house's exterior is currently being hovered"
- **Returns**: isHouseExteriorDoorHovered (bool)

#### IsHouseExteriorHovered
- **Tainted**: No
- **Doc**: "Returns true if the house's exterior is currently being hovered"
- **Returns**: isHouseExteriorHovered (bool)

#### IsHoveringDecor
- **Tainted**: No
- **Doc**: "Returns true if a placed decor instance is currently being hovered"
- **Returns**: isHoveringDecor (bool)

#### IsModeDisabledForPreviewState
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: mode (HouseEditorMode)
- **Returns**: isModeDisabled (bool)

#### IsPreviewState
- **Tainted**: No
- **Returns**: isPreviewState (bool)

#### RemovePlacedDecorEntry
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Placed Decor List APIs currently restricted due to being potentially very expensive operations, may be reworked & opened up in the future"
- **Args**: decorGUID (WOWGUID)

#### RemoveSelectedDecor
- **Tainted**: No
- **Doc**: "Attempt to return the currently selected decor instance back to the house chest"

#### SetGridVisible
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: gridVisible (bool)

#### SetPlacedDecorEntryHovered
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Placed Decor List APIs currently restricted due to being potentially very expensive operations, may be reworked & opened up in the future"
- **Args**: decorGUID (WOWGUID), hovered (bool)

#### SetPlacedDecorEntrySelected
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Placed Decor List APIs currently restricted due to being potentially very expensive operations, may be reworked & opened up in the future"
- **Args**: decorGUID (WOWGUID), selected (bool)

### Structures

#### HousingDecorInstanceListEntry
*Smaller structs with the minimum fields from HousingDecorInstanceInfo needed to identify/display a slim list of placed decor*

| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| decorGUID | WOWGUID | No |  |
| name | cstring | No |  |

### Events

#### HOUSE_DECOR_ADDED_TO_CHEST
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| decorGUID | WOWGUID | No |
| decorID | number | No |

#### HOUSE_EXTERIOR_POSITION_FAILURE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| housingResult | HousingResult | No |

#### HOUSE_EXTERIOR_POSITION_SUCCESS
*SynchronousEvent*

#### HOUSING_DECOR_GRID_VISIBILITY_STATUS_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| isGridVisible | bool | No |

#### HOUSING_DECOR_PLACE_FAILURE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| housingResult | HousingResult | No |

#### HOUSING_DECOR_PLACE_SUCCESS
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| decorGUID | WOWGUID | No |
| size | HousingCatalogEntrySize | No |
| isNew | bool | No |
| isPreview | bool | No |

#### HOUSING_DECOR_PREVIEW_STATE_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| isPreviewState | bool | No |

#### HOUSING_DECOR_REMOVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| decorGUID | WOWGUID | No |

#### HOUSING_DECOR_SELECT_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |

#### HOUSING_NUM_DECOR_PLACED_CHANGED
*SynchronousEvent*

---
## HousingUISharedDocumentation (from HousingUISharedDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Enumerations

#### HouseLevelRewardType
| Name | Value | Documentation |
|------|-------|---------------|
| Value | 0 |  |
| Object | 1 |  |

#### HouseLevelRewardValueType
| Name | Value | Documentation |
|------|-------|---------------|
| ExteriorDecor | 0 |  |
| InteriorDecor | 1 |  |
| Rooms | 2 |  |
| Fixtures | 3 |  |

#### HouseVisitType
| Name | Value | Documentation |
|------|-------|---------------|
| Unknown | 0 |  |
| Friend | 1 |  |
| Guild | 2 |  |
| Party | 3 |  |

### Structures

#### HouseInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| plotID | number | No |  |
| houseName | string | Yes |  |
| ownerName | string | Yes |  |
| plotCost | number | Yes |  |
| neighborhoodName | string | Yes |  |
| moveOutTime | time_t | Yes |  |
| plotReserved | bool | Yes |  |
| neighborhoodGUID | WOWGUID | Yes |  |
| houseGUID | WOWGUID | Yes |  |

#### HouseLevelFavor
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| houseGUID | WOWGUID | Yes |  |
| houseLevel | number | No |  |
| houseFavor | number | No |  |

#### HouseLevelInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| level | number | No | This specific house's current level, determined/increasesd by earning house xp |
| interiorDecorPlacementBudget | number | No | Current max decor placement budget for inside the house; Can be increased via house level |
| exteriorDecorPlacementBudget | number | No | Current max decor placement budget for the house exterior/in the house's plot; Can be increased via house level |
| roomPlacementBudget | number | No | Current max room placement budget for the house; Can be increased via house level |
| exteriorFixtureBudget | number | No |  |

#### HouseLevelReward
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| type | HouseLevelRewardType | No |  |
| asset | ModelAsset | Yes |  |
| iconTexture | FileAsset | Yes |  |
| iconAtlas | textureAtlas | Yes |  |
| objectName | string | Yes |  |
| tooltipText | string | Yes |  |
| valueType | HouseLevelRewardValueType | Yes |  |
| oldValue | number | Yes |  |
| newValue | number | Yes |  |

#### HouseOwnerCharacterInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| characterName | string | No |  |
| classID | number | No |  |
| error | HouseOwnerError | No |  |
| playerGUID | WOWGUID | No |  |

#### HouseholdMemberInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| characterName | string | No |  |
| classID | number | No |  |

#### NeighborhoodInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| neighborhoodType | NeighborhoodType | No |  |
| neighborhoodOwnerType | NeighborhoodOwnerType | No | Default: None.  |
| neighborhoodName | string | No |  |
| neighborhoodGUID | WOWGUID | No |  |
| ownerGUID | WOWGUID | No |  |
| suggestionReason | HouseFinderSuggestionReason | Yes |  |
| ownerName | string | Yes |  |
| locationName | string | Yes |  |

#### NeighborhoodPlotMapInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| mapPosition | vector2 | No |  |
| plotDataID | number | No |  |
| plotID | number | No |  |
| ownerType | HousingPlotOwnerType | No | Default: None.  |
| plotCost | number | Yes |  |
| ownerName | string | Yes |  |

#### NeighborhoodRosterMemberInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| playerGUID | WOWGUID | No |  |
| residentName | string | No |  |
| residentType | ResidentType | No |  |
| isOnline | bool | No |  |
| plotID | number | No |  |
| subdivision | number | Yes |  |

#### NeighborhoodRosterMemberUpdateInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| playerGUID | WOWGUID | No |  |
| residentType | ResidentType | No |  |
| isOnline | bool | No |  |

---
## HousingUI (from HousingUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_Housing
- **Environment**: All

### Functions

#### AcceptNeighborhoodOwnership
- **Tainted**: No

#### CanEditCharter
- **Tainted**: No
- **Returns**: canEditCharter (bool)

#### CanTakeReportScreenshot
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: plotIndex (number)
- **Returns**: reason (InvalidPlotScreenshotReason)

#### CreateGuildNeighborhood
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodName (cstring)

#### CreateNeighborhoodCharter
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodName (cstring)

#### DeclineNeighborhoodOwnership
- **Tainted**: No

#### DoesFactionMatchNeighborhood
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGUID (WOWGUID)
- **Returns**: factionMatches (bool)

#### EditNeighborhoodCharter
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodName (cstring)

#### GetCurrentHouseInfo
- **Tainted**: No
- **Returns**: houseInfo (HouseInfo, nilable)

#### GetCurrentHouseLevelFavor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: houseGuid (WOWGUID)

#### GetCurrentHouseRefundAmount
- **Tainted**: No
- **Returns**: refundAmount (number)

#### GetCurrentNeighborhoodGUID
- **Tainted**: No
- **Returns**: neighborhoodGUID (WOWGUID, nilable)

#### GetHouseLevelFavorForLevel
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: level (number)
- **Returns**: houseFavor (number)

#### GetHouseLevelRewardsForLevel
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: level (number)

#### GetHousingAccessFlags
- **Tainted**: No
- **Returns**: accessFlags (HouseSettingFlags)

#### GetMaxHouseLevel
- **Tainted**: No
- **Returns**: level (number)

#### GetNeighborhoodTextureSuffix
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGUID (WOWGUID)
- **Returns**: neighborhoodTextureSuffix (cstring)

#### GetOthersOwnedHouses
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: playerGUID (WOWGUID, nilable), bnetID (number, nilable), isInPlayersGuild (bool)

#### GetPlayerOwnedHouses
- **Tainted**: No

#### GetTrackedHouseGuid
- **Tainted**: No
- **Returns**: trackedHouse (WOWGUID, nilable)

#### GetUIMapIDForNeighborhood
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGuid (WOWGUID)
- **Returns**: uiMapID (number, nilable)

#### GetVisitCooldownInfo
- **Tainted**: No
- **Returns**: spellCooldownInfo (SpellCooldownInfo)

#### HasHousingExpansionAccess
- **Tainted**: No
- **Returns**: hasAccess (bool)

#### HouseFinderDeclineNeighborhoodInvitation
- **Tainted**: No

#### HouseFinderRequestNeighborhoods
- **Tainted**: No

#### HouseFinderRequestReservationAndPort
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGuid (WOWGUID), plotID (number)

#### IsHousingMarketEnabled
- **Tainted**: No
- **Returns**: isHousingMarketEnabled (bool)

#### IsHousingMarketShopEnabled
- **Tainted**: No
- **Returns**: isHousingMarketShopEnabled (bool)

#### IsHousingServiceEnabled
- **Tainted**: No
- **Returns**: isAvailable (bool)

#### IsInsideHouse
- **Tainted**: No
- **Returns**: isInside (bool)

#### IsInsideHouseOrPlot
- **Tainted**: No
- **Returns**: isInside (bool)

#### IsInsideOwnHouse
- **Tainted**: No
- **Returns**: isInsideOwnHouse (bool)

#### IsInsidePlot
- **Tainted**: No
- **Returns**: isInside (bool)

#### IsOnNeighborhoodMap
- **Tainted**: No
- **Returns**: isOnNeighborhoodMap (bool)

#### LeaveHouse
- **Tainted**: No

#### OnCharterConfirmationAccepted
- **Tainted**: No

#### OnCharterConfirmationClosed
- **Tainted**: No

#### OnCreateCharterNeighborhoodClosed
- **Tainted**: No

#### OnCreateGuildNeighborhoodClosed
- **Tainted**: No

#### OnHouseFinderClickPlot
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: plotID (number)

#### OnRequestSignatureClicked
- **Tainted**: No

#### OnSignCharterClicked
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: charterOwnerGUID (WOWGUID)

#### RelinquishHouse
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: houseGuid (WOWGUID)

#### RequestCurrentHouseInfo
- **Tainted**: No

#### RequestHouseFinderNeighborhoodData
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGuid (WOWGUID), neighborhoodName (cstring)

#### RequestPlayerCharacterList
- **Tainted**: No

#### ReturnAfterVisitingHouse
- **Tainted**: No

#### SaveHouseSettings
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: playerGUID (WOWGUID), accessFlags (HouseSettingFlags)

#### SearchBNetFriendNeighborhoods
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: bnetName (cstring)
- **Returns**: isValidBnetFriend (bool)

#### SearchBNetFriendNeighborhoodsByID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: bnetID (number)
- **Returns**: isValidBnetFriend (bool)

#### SetTrackedHouseGuid
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: trackedHouse (WOWGUID, nilable)

#### StartTutorial
- **Tainted**: No

#### TeleportHome
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGUID (WOWGUID), houseGUID (WOWGUID), plotID (number)

#### TryRenameNeighborhood
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodName (cstring)

#### ValidateCreateGuildNeighborhoodSize
- **Tainted**: No

#### ValidateNeighborhoodName
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodName (cstring)

#### VisitHouse
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: neighborhoodGUID (WOWGUID), houseGUID (WOWGUID), plotID (number)

### Enumerations

#### CreateNeighborhoodErrorType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Profanity | 1 |  |
| UndersizedGuild | 2 |  |
| OversizedGuild | 3 |  |

#### HousingItemToastType
| Name | Value | Documentation |
|------|-------|---------------|
| Room | 0 |  |
| Fixture | 1 |  |
| Customization | 2 |  |
| Decor | 3 |  |
| House | 4 |  |

### Events

#### ADD_NEIGHBORHOOD_CHARTER_SIGNATURE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| signature | cstring | No |

#### B_NET_NEIGHBORHOOD_LIST_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |
| neighborhoodInfos | table<NeighborhoodInfo> | Yes |

#### CLOSE_CHARTER_CONFIRMATION_UI
*SynchronousEvent*

#### CLOSE_CREATE_CHARTER_NEIGHBORHOOD_UI
*SynchronousEvent*

#### CLOSE_CREATE_GUILD_NEIGHBORHOOD_UI
*SynchronousEvent*

#### CREATE_NEIGHBORHOOD_RESULT
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |
| neighborhoodName | cstring | Yes |

#### CURRENT_HOUSE_INFO_RECIEVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| houseInfo | HouseInfo | No |

#### CURRENT_HOUSE_INFO_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| houseInfo | HouseInfo | No |

#### DECLINE_NEIGHBORHOOD_INVITATION_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| success | bool | No |

#### FORCE_REFRESH_HOUSE_FINDER
*SynchronousEvent*

#### HOUSE_FINDER_NEIGHBORHOOD_DATA_RECIEVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodPlots | table<NeighborhoodPlotMapInfo> | No |

#### HOUSE_INFO_UPDATED
*SynchronousEvent*

#### HOUSE_LEVEL_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| newHouseLevelInfo | HouseLevelInfo | Yes |

#### HOUSE_LEVEL_FAVOR_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| houseLevelFavor | HouseLevelFavor | No |

#### HOUSE_PLOT_ENTERED
*SynchronousEvent*

#### HOUSE_PLOT_EXITED
*SynchronousEvent*

#### HOUSE_RESERVATION_RESPONSE_RECIEVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |

#### HOUSING_MARKET_AVAILABILITY_UPDATED
*SynchronousEvent*

#### HOUSING_SERVICES_AVAILABILITY_UPDATED
*SynchronousEvent*

#### MOVE_OUT_RESERVATION_UPDATED
*SynchronousEvent*

#### NEIGHBORHOOD_GUILD_SIZE_VALIDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| approved | bool | No |

#### NEIGHBORHOOD_LIST_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |
| neighborhoodInfos | table<NeighborhoodInfo> | Yes |

#### NEIGHBORHOOD_NAME_VALIDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| approved | bool | No |

#### NEW_HOUSING_ITEM_ACQUIRED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| itemType | HousingItemToastType | No |
| itemName | cstring | No |
| icon | fileID | Yes |

#### OPEN_CHARTER_CONFIRMATION_UI
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodName | string | No |
| locationName | string | No |

#### OPEN_CREATE_CHARTER_NEIGHBORHOOD_UI
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| locationName | cstring | No |

#### OPEN_CREATE_GUILD_NEIGHBORHOOD_UI
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| locationName | cstring | No |

#### OPEN_NEIGHBORHOOD_CHARTER
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodInfo | NeighborhoodInfo | No |
| signatures | table<string> | No |
| requiredSignatures | number | No |

#### OPEN_NEIGHBORHOOD_CHARTER_SIGNATURE_REQUEST
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodInfo | NeighborhoodInfo | No |

#### PLAYER_CHARACTER_LIST_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| characterInfos | table<HouseOwnerCharacterInfo> | No |
| ownerListIndex | number | No |

#### PLAYER_HOUSE_LIST_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| houseInfos | table<HouseInfo> | No |

#### RECEIVED_HOUSE_LEVEL_REWARDS
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| level | number | No |
| rewards | table<HouseLevelReward> | No |

#### REMOVE_NEIGHBORHOOD_CHARTER_SIGNATURE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| signature | cstring | No |

#### SHOW_NEIGHBORHOOD_OWNERSHIP_TRANSFER_DIALOG
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodName | cstring | No |
| cosmeticOwnerName | cstring | No |

#### TRACKED_HOUSE_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| trackedHouse | WOWGUID | Yes |

#### VIEW_HOUSES_LIST_RECIEVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| houseInfos | table<HouseInfo> | No |

---
## PlayerHousingConstantsDocumentation (from PlayerHousingConstantsDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Enumerations

#### HouseEditingContext
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Decor | 1 |  |
| Room | 2 |  |
| Fixture | 3 |  |

#### HouseEditorMode
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| BasicDecor | 1 |  |
| ExpertDecor | 2 |  |
| Layout | 3 |  |
| Customize | 4 |  |
| Cleanup | 5 |  |
| ExteriorCustomization | 6 |  |

#### HouseExteriorWMODataFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| UnlockedByDefault | 1 |  |
| AllowedInHordeNeighborhoods | 2 |  |
| AllowedInAllianceNeighborhoods | 4 |  |

#### HouseFinderSuggestionReason
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Owner | 1 |  |
| CharterInvite | 2 |  |
| Guild | 4 |  |
| BNetFriends | 8 |  |
| PartySync | 16 |  |
| Random | 32 |  |

#### HouseOwnerError
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Faction | 1 |  |
| Guild | 2 |  |
| GenericPermission | 3 |  |

#### HousingDecorTheme
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Folk | 1 |  |
| Rugged | 2 |  |
| Generic | 3 |  |
| NightElf | 4 |  |
| BloodElf | 5 |  |

#### HousingFixtureFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| IsDefaultFixture | 1 |  |
| UnlockedByDefault | 2 |  |

#### HousingFixtureSize
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Any | 1 |  |
| Small | 2 |  |
| Medium | 3 |  |
| Large | 4 |  |

#### HousingFixtureType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Base | 9 |  |
| Roof | 10 |  |
| Door | 11 |  |
| Window | 12 |  |
| RoofDetail | 13 |  |
| RoofWindow | 14 |  |
| Tower | 15 |  |
| Chimney | 16 |  |

#### HousingLayoutRestriction
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| RoomNotFound | 1 |  |
| NotInsideHouse | 2 |  |
| NotHouseOwner | 3 |  |
| IsBaseRoom | 4 |  |
| RoomNotLeaf | 5 |  |
| StairwellConnection | 6 |  |
| LastRoom | 7 |  |
| UnreachableRoom | 8 |  |
| SingleDoor | 9 |  |

#### HousingPlotOwnerType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Stranger | 1 |  |
| Friend | 2 |  |
| Self | 3 |  |

#### HousingResult
| Name | Value | Documentation |
|------|-------|---------------|
| Success | 0 |  |
| ActionLockedByCombat | 1 |  |
| BoundsFailureChildren | 2 |  |
| BoundsFailurePlot | 3 |  |
| BoundsFailureRoom | 4 |  |
| CannotAfford | 5 |  |
| CharterComplete | 6 |  |
| CollisionInvalid | 7 |  |
| DbError | 8 |  |
| DecorCannotBeRedeemed | 9 |  |
| DecorItemNotDestroyable | 10 |  |
| DecorNotFound | 11 |  |
| DecorNotFoundInStorage | 12 |  |
| DuplicateCharterSignature | 13 |  |
| FilterRejected | 14 |  |
| FixtureCantDeleteDoor | 15 |  |
| FixtureHookEmpty | 16 |  |
| FixtureHookOccupied | 17 |  |
| FixtureHouseTypeMismatch | 18 |  |
| FixtureNotFound | 19 |  |
| FixtureSizeMismatch | 20 |  |
| FixtureTypeMismatch | 21 |  |
| GenericFailure | 22 |  |
| GuildMoreAccountsNeeded | 23 |  |
| GuildMoreActivePlayersNeeded | 24 |  |
| GuildNotLoaded | 25 |  |
| HouseEditLockFailed | 26 |  |
| HouseExteriorAlreadyThatSize | 27 |  |
| HouseExteriorAlreadyThatType | 28 |  |
| HouseExteriorRootNotFound | 29 |  |
| HouseExteriorTypeNeighborhoodMismatch | 30 |  |
| HouseExteriorTypeNotFound | 31 |  |
| HouseExteriorTypeSizeMismatch | 32 |  |
| HouseExteriorSizeNotAvailable | 33 |  |
| HookNotChildOfFixture | 34 |  |
| HouseNotFound | 35 |  |
| IncorrectFaction | 36 |  |
| InvalidDecorItem | 37 |  |
| InvalidDistance | 38 |  |
| InvalidGuild | 39 |  |
| InvalidHouse | 40 |  |
| InvalidInstance | 41 |  |
| InvalidInteraction | 42 |  |
| InvalidMap | 43 |  |
| InvalidNeighborhoodName | 44 |  |
| InvalidRoomLayout | 45 |  |
| LockedByOtherPlayer | 46 |  |
| LockOperationFailed | 47 |  |
| MaxDecorReached | 48 |  |
| MaxPreviewDecorReached | 49 |  |
| MissingCoreFixture | 50 |  |
| MissingDye | 51 |  |
| MissingExpansionAccess | 52 |  |
| MissingFactionMap | 53 |  |
| MissingPrivateNeighborhoodInvite | 54 |  |
| MoreHouseSlotsNeeded | 55 |  |
| MoreSignaturesNeeded | 56 |  |
| NeighborhoodNotFound | 57 |  |
| NoNeighborhoodOwnershipRequests | 58 |  |
| NotInDecorEditMode | 59 |  |
| NotInFixtureEditMode | 60 |  |
| NotInLayoutEditMode | 61 |  |
| NotInsideHouse | 62 |  |
| NotOnOwnedPlot | 63 |  |
| OperationAborted | 64 |  |
| OwnerNotInGuild | 65 |  |
| PermissionDenied | 66 |  |
| PlacementTargetInvalid | 67 |  |
| PlayerNotFound | 68 |  |
| PlayerNotInInstance | 69 |  |
| PlotNotFound | 70 |  |
| PlotNotVacant | 71 |  |
| PlotReservationCooldown | 72 |  |
| PlotReserved | 73 |  |
| RoomNotFound | 74 |  |
| RoomUpdateFailed | 75 |  |
| RpcFailure | 76 |  |
| ServiceNotAvailable | 77 |  |
| StaticDataNotFound | 78 |  |
| TimeoutLimit | 79 |  |
| TimerunningNotAllowed | 80 |  |
| TokenRequired | 81 |  |
| TooManyRequests | 82 |  |
| TransactionFailure | 83 |  |
| UncollectedExteriorFixture | 84 |  |
| UncollectedHouseType | 85 |  |
| UncollectedRoom | 86 |  |
| UncollectedRoomMaterial | 87 |  |
| UncollectedRoomTheme | 88 |  |
| UnlockOperationFailed | 89 |  |

#### HousingRoomComponentCeilingType
| Name | Value | Documentation |
|------|-------|---------------|
| Flat | 0 |  |
| Vaulted | 1 |  |

#### HousingRoomComponentDoorType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Doorway | 1 |  |
| Threshold | 2 |  |

#### HousingRoomComponentFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| HiddenInLayoutMode | 1 |  |

#### HousingRoomComponentFloorType
| Name | Value | Documentation |
|------|-------|---------------|
| Floor | 0 |  |

#### HousingRoomComponentOptionFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| IsDefault | 1 |  |

#### HousingRoomComponentOptionType
| Name | Value | Documentation |
|------|-------|---------------|
| Cosmetic | 0 |  |
| DoorwayWall | 1 |  |
| Doorway | 2 |  |

#### HousingRoomComponentStairType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| StartToEnd | 1 |  |
| StartToMiddle | 2 |  |
| MiddleToMiddle | 3 |  |
| MiddleToEnd | 4 |  |

#### HousingRoomComponentTextureFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| UnlockedByDefault | 1 |  |

#### HousingRoomComponentType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Wall | 1 |  |
| Floor | 2 |  |
| Ceiling | 3 |  |
| Stairs | 4 |  |
| Pillar | 5 |  |
| DoorwayWall | 6 |  |
| Doorway | 7 |  |

#### HousingRoomFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| BaseRoom | 1 |  |
| HasStairs | 2 |  |
| UnlockedByDefault | 4 |  |
| HasCustomGeometry | 8 |  |

#### HousingThemeFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| UnlockedByDefault | 1 |  |
| ShowInStyleSelector | 2 |  |

#### HousingThrottleType
| Name | Value | Documentation |
|------|-------|---------------|
| General | 0 |  |
| Decoration | 1 |  |

#### NeighborhoodFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| PoolParent | 1 |  |
| OpenToPublic | 2 |  |

#### NeighborhoodInviteResult
| Name | Value | Documentation |
|------|-------|---------------|
| Success | 0 |  |
| DbError | 1 |  |
| RpcFailure | 2 |  |
| GenericFailure | 3 |  |
| Permission | 4 |  |
| Faction | 5 |  |
| PendingInvitation | 6 |  |
| InviteLimit | 7 |  |
| NotEnoughPlots | 8 |  |
| NotFound | 9 |  |
| TooManyRequests | 10 |  |

#### NeighborhoodMapFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| AlliancePurchasable | 1 |  |
| HordePurchasable | 2 |  |
| CanSystemGenerate | 4 |  |

#### RetroactiveDecorRewardFlags
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| AllCriteriaRequired | 1 |  |

#### RoomConnectionType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| All | 1 |  |

---
## MerchantFrame (from MerchantFrameDocumentation.lua)
- **Type**: System
- **Namespace**: C_MerchantFrame
- **Environment**: All

### Functions

#### GetBuybackItemID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: buybackSlotIndex (luaIndex)
- **Returns**: buybackItemID (number)

#### GetItemInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: index (luaIndex)
- **Returns**: info (MerchantItemInfo)

#### GetNumJunkItems
- **Tainted**: No
- **Returns**: numJunkItems (number)

#### IsMerchantItemRefundable
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: index (luaIndex)
- **Returns**: refundable (bool)

#### IsSellAllJunkEnabled
- **Tainted**: No
- **Returns**: enabled (bool)

#### SellAllJunkItems
- **Tainted**: No

### Structures

#### MerchantItemInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| name | string | Yes |  |
| texture | fileID | No |  |
| price | number | No | Default: 0.  |
| stackCount | number | No | Default: 0.  |
| numAvailable | number | No | Default: 0.  |
| isPurchasable | bool | No | Default: False.  |
| isUsable | bool | No | Default: False.  |
| hasExtendedCost | bool | No | Default: False.  |
| currencyID | number | Yes |  |
| spellID | number | Yes |  |
| isQuestStartItem | bool | No | Default: False.  |

### Events

#### MERCHANT_CLOSED
*SynchronousEvent*

#### MERCHANT_FILTER_ITEM_UPDATE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| itemID | number | No |

#### MERCHANT_SHOW
*SynchronousEvent*

#### MERCHANT_UPDATE
*SynchronousEvent*

---
## HousingLayoutPinFrameAPI (from HousingLayoutPinFrameAPIDocumentation.lua)
- **Type**: ScriptObject
- **Environment**: All

### Functions

#### CanMove
- **Tainted**: No
- **Returns**: moveRestriction (HousingLayoutRestriction)

#### CanRemove
- **Tainted**: No
- **Returns**: removalRestriction (HousingLayoutRestriction)

#### CanRotate
- **Tainted**: No
- **Returns**: rotateRestriction (HousingLayoutRestriction)

#### Drag
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: isAccessible (bool)

#### GetDoorConnectionInfo
- **Tainted**: No
- **Returns**: connectionInfo (DoorConnectionInfo, nilable)

#### GetPinType
- **Tainted**: No
- **Returns**: type (HousingLayoutPinType)

#### GetRoomGUID
- **Tainted**: No
- **Returns**: roomGUID (WOWGUID)

#### GetRoomName
- **Tainted**: No
- **Returns**: name (cstring, nilable)

#### IsAnyPartOfRoomSelected
- **Tainted**: No
- **Doc**: "Returns true if this pin's associated room, or anything attached to it, is selected. Ex: If pin is for a door, returns true if its room, or any other doors on that room, are selected"
- **Returns**: isSelected (bool)

#### IsOccupiedDoor
- **Tainted**: No
- **Doc**: "Will be nil if pin is not a Door"
- **Returns**: isOccupied (bool, nilable)

#### IsSelected
- **Tainted**: No
- **Doc**: "Returns true if this pin's object is itself selected; See IsAnyPartOfRoomSelected for a broader Selected check"
- **Returns**: isSelected (bool)

#### IsValid
- **Tainted**: No
- **Returns**: isValid (bool)

#### IsValidForSelectedFloorplan
- **Tainted**: No
- **Returns**: isValid (bool)

#### Select
- **Tainted**: No

#### SetUpdateCallback
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: cb (PinUpdatedCallback)

---
## HousingFixturePointFrameAPI (from HousingFixturePointFrameAPIDocumentation.lua)
- **Type**: ScriptObject
- **Environment**: All

### Functions

#### HasAttachedFixture
- **Tainted**: No
- **Returns**: hasAttachedFixture (bool)

#### IsSelected
- **Tainted**: No
- **Returns**: isSelected (bool)

#### IsValid
- **Tainted**: No
- **Returns**: isValid (bool)

#### Select
- **Tainted**: No

#### SetUpdateCallback
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: cb (FixturePointUpdatedCallback)

### Callback Types

- **FixturePointUpdatedCallback**

---
## HouseEditorUI (from HouseEditorUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HouseEditor
- **Environment**: All

### Functions

#### ActivateHouseEditorMode
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempts switch the House Editor to a specific House Editor mode"
- **Args**: editMode (HouseEditorMode)
- **Returns**: result (HousingResult) — The initial result of the attempt to activate the mode; If Success, mode is either already active, or we've succesfully started making required requests to server; Listen for MODE_CHANGED or MODE_CHANGE_FAILURE events for ultimate end result after server calls

#### EnterHouseEditor
- **Tainted**: No
- **Doc**: "Attempts to open the House Editor to the default House Editor mode"
- **Returns**: result (HousingResult) — The initial result of the attempt to open the Editor; If Success, Editor is either already active, or we've succesfully started making required requests to server; Listen for MODE_CHANGED or MODE_CHANGE_FAILURE events for ultimate end result after server calls

#### GetActiveHouseEditorMode
- **Tainted**: No
- **Returns**: editMode (HouseEditorMode)

#### GetHouseEditorAvailability
- **Tainted**: No
- **Doc**: "Returns the availability state of the House Editor overall"
- **Returns**: result (HousingResult)

#### GetHouseEditorModeAvailability
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Returns the availability of a specific House Editor mode"
- **Args**: editMode (HouseEditorMode)
- **Returns**: result (HousingResult)

#### IsHouseEditorActive
- **Tainted**: No
- **Doc**: "Returns whether the House Editor is active, in any mode"
- **Returns**: isEditorActive (bool)

#### IsHouseEditorModeActive
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Returns whether the specific House Editor mode is active"
- **Args**: editMode (HouseEditorMode)
- **Returns**: isModeActive (bool)

#### IsHouseEditorStatusAvailable
- **Tainted**: No
- **Doc**: "Returns true if the HouseEditor currently able process mode availability and switching; May be false if not in a house or plot, or while waiting to get house settings back from the server"
- **Returns**: editorStatusAvailable (bool)

#### LeaveHouseEditor
- **Tainted**: No

### Events

#### HOUSE_EDITOR_AVAILABILITY_CHANGED
*SynchronousEvent*

#### HOUSE_EDITOR_MODE_CHANGE_FAILURE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |

#### HOUSE_EDITOR_MODE_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| currentEditMode | HouseEditorMode | No |

---
## HousingLayoutUI (from HousingLayoutUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingLayout
- **Environment**: All

### Functions

#### AnyRoomsOnFloor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: floor (number)
- **Returns**: anyRooms (bool)

#### CancelActiveLayoutEditing
- **Tainted**: No

#### ConfirmStairChoice
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: choice (HousingLayoutStairDirection, nilable) — If not set, the pending stair operation will be cancelled

#### DeselectFloorplan
- **Tainted**: No

#### DeselectRoomOrDoor
- **Tainted**: No

#### GetNumActiveRooms
- **Tainted**: No
- **Returns**: numRooms (number)

#### GetRoomPlacementBudget
- **Tainted**: No
- **Doc**: "Returns the max room placement budget for the current house interior; Can be increased via house level"
- **Returns**: placementBudget (number)

#### GetSelectedDoor
- **Tainted**: No
- **Doc**: "If a door is selected, returns its component id and the guid of the room it belongs to; Otherwise returns nothing"
- **Returns**: selectedDoorComponentID (number), roomGUID (WOWGUID)

#### GetSelectedFloorplan
- **Tainted**: No
- **Returns**: roomID (number, nilable)

#### GetSelectedRoom
- **Tainted**: No
- **Doc**: "If a Room is selected, returns the room's guid; Otherwise returns nothing"
- **Returns**: roomGUID (WOWGUID)

#### GetSelectedStairwellRoomCount
- **Tainted**: No
- **Returns**: stairwellRoomCount (number)

#### GetSpentPlacementBudget
- **Tainted**: No
- **Doc**: "Returns how much of the current house's room placement budget has been spent; Different kinds of rooms take up different budget amounts, so this value isn't an individual room count, see GetNumActiveRooms for that"
- **Returns**: spentPlacementBudget (number)

#### GetViewedFloor
- **Tainted**: No
- **Returns**: floor (number)

#### HasAnySelections
- **Tainted**: No
- **Doc**: "Returns true if any room, door, or floorplan is currently selected or being dragged"
- **Returns**: hasAnySelections (bool)

#### HasRoomPlacementBudget
- **Tainted**: No
- **Doc**: "Returns whether there's a max room placement budget available and active for the current player, in the current house interior"
- **Returns**: hasBudget (bool)

#### HasSelectedDoor
- **Tainted**: No
- **Doc**: "Returns true if a door component is currently selected"
- **Returns**: hasSelectedDoor (bool)

#### HasSelectedFloorplan
- **Tainted**: No
- **Returns**: hasSelectedFloorplan (bool)

#### HasSelectedRoom
- **Tainted**: No
- **Doc**: "Returns true if a room is selected, will NOT return true if a door is selected"
- **Returns**: hasSelectedRoom (bool)

#### HasStairs
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: roomRecordID (number)
- **Returns**: hasStairs (bool)

#### HasValidConnection
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: roomGUID (WOWGUID), componentID (number), roomId (number)
- **Returns**: canPlace (bool)

#### IsBaseRoom
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: roomGUID (WOWGUID)
- **Returns**: isBaseRoom (bool)

#### IsDraggingRoom
- **Tainted**: No
- **Returns**: isDragging (bool), isAccessibleDrag (bool)

#### MoveDraggedRoom
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to move the room currently being dragged to a specific connection point on a specific other room"
- **Args**: sourceDoorIndex (number), destRoom (WOWGUID), destDoorIndex (number)

#### MoveLayoutCamera
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: direction (HousingLayoutCameraDirection), isPressed (bool)

#### RemoveRoom
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to return a previously placed room to the House Chest"
- **Args**: roomGUID (WOWGUID)

#### RotateFocusedRoom
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Rotates either the currently dragged or currently selected room, if either exist"
- **Args**: isLeft (bool)

#### RotateRoom
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to rotate an already placed room"
- **Args**: roomGUID (WOWGUID), isLeft (bool)

#### SelectFloorplan
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: roomID (number)

#### SetViewedFloor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: floor (number)

#### StartDrag
- **Tainted**: No

#### StopDrag
- **Tainted**: No

#### StopDraggingRoom
- **Tainted**: No

#### ZoomLayoutCamera
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: zoomIn (bool)
- **Returns**: zoomChanged (bool)

### Events

#### HOUSING_LAYOUT_DOOR_SELECTED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| roomGUID | WOWGUID | No |
| componentID | number | No |

#### HOUSING_LAYOUT_DOOR_SELECTION_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelection | bool | No |

#### HOUSING_LAYOUT_DRAG_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| isDraggingRoom | bool | No |

#### HOUSING_LAYOUT_FLOORPLAN_SELECTION_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelection | bool | No |
| roomID | number | No |

#### HOUSING_LAYOUT_NUM_FLOORS_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| prevNumFloors | number | No |
| numFloors | number | No |

#### HOUSING_LAYOUT_PIN_FRAME_ADDED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| pinFrame | HousingLayoutPinFrame | No |

#### HOUSING_LAYOUT_PIN_FRAME_RELEASED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| pinFrame | HousingLayoutPinFrame | No |

#### HOUSING_LAYOUT_PIN_FRAMES_RELEASED
*SynchronousEvent*

#### HOUSING_LAYOUT_ROOM_COMPONENT_THEME_SET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| roomGUID | WOWGUID | No |
| componentID | number | No |
| newThemeSet | number | No |
| result | HousingResult | No |

#### HOUSING_LAYOUT_ROOM_MOVE_INVALID
*SynchronousEvent*

#### HOUSING_LAYOUT_ROOM_MOVED
*SynchronousEvent*

#### HOUSING_LAYOUT_ROOM_RECEIVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| prevNumFloors | number | No |
| currNumFloors | number | No |
| isUpstairs | bool | No |

#### HOUSING_LAYOUT_ROOM_REMOVED
*SynchronousEvent*

#### HOUSING_LAYOUT_ROOM_RETURNED
*SynchronousEvent*

#### HOUSING_LAYOUT_ROOM_SELECTION_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelection | bool | No |

#### HOUSING_LAYOUT_ROOM_SNAPPED
*SynchronousEvent*

#### HOUSING_LAYOUT_VIEWED_FLOOR_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| floor | number | No |

#### SHOW_STAIR_DIRECTION_CONFIRMATION
*SynchronousEvent*

---
## HousingLayoutUITypesDocumentation (from HousingLayoutUITypesDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Enumerations

#### HousingLayoutCameraDirection
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Up | 1 |  |
| Down | 2 |  |
| Left | 4 |  |
| Right | 8 |  |

#### HousingLayoutPinType
| Name | Value | Documentation |
|------|-------|---------------|
| Door | 0 |  |
| Room | 1 |  |

#### HousingLayoutStairDirection
| Name | Value | Documentation |
|------|-------|---------------|
| Up | 0 |  |
| Down | 1 |  |

### Structures

#### DoorConnectionInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| doorID | number | No |  |
| connectionType | HousingRoomComponentType | No |  |
| doorFacing | number | No |  |

#### RoomOptionInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| roomName | cstring | No |  |
| roomID | number | No |  |
| learned | bool | No |  |
| numOwned | number | No |  |

### Callback Types

- **PinUpdatedCallback**

---
## DyeColorInfo (from DyeColorInfoDocumentation.lua)
- **Type**: System
- **Namespace**: C_DyeColor
- **Environment**: All

### Functions

#### GetAllDyeColorCategories
- **Tainted**: No
- **Returns**: dyeColorCategoryIDs (table<number>)

#### GetAllDyeColors
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: ownedColorsOnly (bool)
- **Returns**: dyeColorIDs (table<number>)

#### GetDyeColorCategoryInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: dyeColorCategoryID (number)
- **Returns**: dyeColorCategoryInfo (DyeColorCategoryDisplayInfo, nilable)

#### GetDyeColorForItem
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: itemLinkOrID (ItemInfo)
- **Returns**: dyeColorID (number, nilable)

#### GetDyeColorForItemLocation
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: itemLocation (ItemLocation)
- **Returns**: dyeColorID (number, nilable)

#### GetDyeColorInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: dyeColorID (number)
- **Returns**: dyeColorInfo (DyeColorDisplayInfo, nilable)

#### GetDyeColorsInCategory
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: dyeColorCategory (number), ownedColorsOnly (bool)
- **Returns**: dyeColorIDs (table<number>)

#### IsDyeColorOwned
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "True if the player owns any of the consumable item used to apply the specified dye"
- **Args**: dyeColorID (number)
- **Returns**: isOwned (bool)

### Events

#### DYE_COLOR_CATEGORY_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| dyeColorCategoryID | number | No |

#### DYE_COLOR_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| dyeColorID | number | No |

---
## DyeColorInfoSharedDocumentation (from DyeColorInfoSharedDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Structures

#### DyeColorCategoryDisplayInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| ID | number | No |  |
| name | cstring | No |  |

#### DyeColorDisplayInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| ID | number | No |  |
| dyeColorCategoryID | number | No |  |
| name | cstring | No |  |
| sortOrder | number | No |  |
| swatchColorStart | colorRGB | No |  |
| swatchColorEnd | colorRGB | No |  |
| itemID | number | Yes | The consumable item used to apply this Dye Color; May be nil if dye color does not have an associated item |
| numOwned | number | No | The number of this dye's consumable item owned by the player; Includes both held and banked items; Will be 0 if dye has no associated item |

---
## HousingBasicModeUI (from HousingBasicModeUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingBasicMode
- **Environment**: All

### Functions

#### CancelActiveEditing
- **Tainted**: No
- **Doc**: "Cancels all in-progress editing of the selected target, which will reset any unsaved changes and deselect the active target; Un-placed decor will be returned to the house chest"

#### CommitDecorMovement
- **Tainted**: No
- **Doc**: "Attempt to save the changes made to the currently selected decor instance"

#### CommitHouseExteriorPosition
- **Tainted**: No
- **Doc**: "Attempt to save the changes made to the House Exterior's position within the plot"

#### FinishPlacingNewDecor
- **Tainted**: No

#### GetHoveredDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the placed decor instance currently being hovered, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetSelectedDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the decor instance that's currently selected, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### IsDecorSelected
- **Tainted**: No
- **Doc**: "Returns true if a decor instance is currently selected and being dragged"
- **Returns**: hasSelectedDecor (bool)

#### IsFreePlaceEnabled
- **Tainted**: No
- **Doc**: "When free place is enabled, collision checks while dragging decor/the house exterior are ignored"
- **Returns**: freePlaceEnabled (bool)

#### IsGridSnapEnabled
- **Tainted**: No
- **Returns**: isGridSnapEnabled (bool)

#### IsGridVisible
- **Tainted**: No
- **Returns**: gridVisible (bool)

#### IsHouseExteriorHovered
- **Tainted**: No
- **Doc**: "Returns true if the house's exterior is currently being hovered"
- **Returns**: isHouseExteriorHovered (bool)

#### IsHouseExteriorSelected
- **Tainted**: No
- **Doc**: "Returns true if the house's exterior is currently selected and being moved"
- **Returns**: isHouseExteriorSelected (bool)

#### IsHoveringDecor
- **Tainted**: No
- **Doc**: "Returns true if a placed decor instance is currently being hovered"
- **Returns**: isHoveringDecor (bool)

#### IsPlacingNewDecor
- **Tainted**: No
- **Returns**: hasPendingDecor (bool)

#### RemoveSelectedDecor
- **Tainted**: No
- **Doc**: "Attempt to return the currently selected decor instance back to the house chest"

#### RotateDecor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Rotates the currently selected decor along a single axis; For wall decor, rotates such that the object stays flat against its current wall; For all other decor, rotates around the Z (vertical) axis"
- **Args**: rotDegrees (number)

#### RotateHouseExterior
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Rotates the House Exterior around the Z (vertical) axis"
- **Args**: rotDegrees (number)

#### SetFreePlaceEnabled
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Set whether free place is enabled; When free place is enabled, collision checks while dragging decor/the house exterior are ignored"
- **Args**: freePlaceEnabled (bool)

#### SetGridSnapEnabled
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: isGridSnapEnabled (bool)

#### SetGridVisible
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: gridVisible (bool)

#### StartPlacingNewDecor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: catalogEntryID (HousingCatalogEntryID)

#### StartPlacingPreviewDecor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: decorRecordID (number), bundleCatalogShopProductID (number, nilable)

### Enumerations

#### HousingBasicModeTargetType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Decor | 1 |  |
| House | 2 |  |

### Events

#### HOUSING_BASIC_MODE_HOVERED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasHoveredTarget | bool | No |
| targetType | HousingBasicModeTargetType | No |

#### HOUSING_BASIC_MODE_PLACEMENT_FLAGS_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| targetType | HousingBasicModeTargetType | No |
| activeFlags | HousingDecorPlacementRestriction | No |

#### HOUSING_BASIC_MODE_SELECTED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelectedTarget | bool | No |
| targetType | HousingBasicModeTargetType | No |
| isPreview | bool | No |

#### HOUSING_DECOR_FREE_PLACE_STATUS_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| isFreePlaceEnabled | bool | No |

#### HOUSING_DECOR_GRID_SNAP_OCCURRED
*SynchronousEvent*

#### HOUSING_DECOR_GRID_SNAP_STATUS_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| isGridSnapEnabled | bool | No |

---
## HousingCleanupModeUI (from HousingCleanupModeUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingCleanupMode
- **Environment**: All

### Functions

#### GetHoveredDecorInfo
- **Tainted**: No
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### IsHoveringDecor
- **Tainted**: No
- **Returns**: isHoveringDecor (bool)

#### RemoveSelectedDecor
- **Tainted**: No

### Events

#### HOUSING_CLEANUP_MODE_HOVERED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasHoveredTarget | bool | No |

#### HOUSING_CLEANUP_MODE_TARGET_SELECTED
*SynchronousEvent*

---
## HousingCustomizeModeUI (from HousingCustomizeModeUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingCustomizeMode
- **Environment**: All

### Functions

#### ApplyDyeToSelectedDecor
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "If a dyeable decor is selected, applies a specific dye color in a specific slot as a preview; See CommitDyesForSelectedDecor to actually save applied dye changes"
- **Args**: dyeSlotID (number), dyeColorID (number, nilable) — If not provided, clears the dye from the specified dye slot, returning that part of the decor asset to its default color

#### ApplyThemeToRoom
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to apply a specific theme set (aka style) to all applicable room components in the current room"
- **Args**: themeSetID (number)

#### ApplyThemeToSelectedRoomComponent
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to apply a specific theme set (aka style) to the currently selected room component only"
- **Args**: themeSetID (number)

#### ApplyWallpaperToAllWalls
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to apply a specific wallpaper (aka material/texture) to all applicable room components in the current room"
- **Args**: roomComponentTextureRecID (number)

#### ApplyWallpaperToSelectedRoomComponent
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to apply a specific wallpaper (aka material/texture) to the currently selected room component only"
- **Args**: roomComponentTextureRecID (number)

#### CancelActiveEditing
- **Tainted**: No
- **Doc**: "Cancels all in-progress editing of the selected target, which will reset any unapplied customization changes and deselect the active target"

#### ClearDyesForSelectedDecor
- **Tainted**: No
- **Doc**: "Clears all previewed dye changes on the selected decor; Does not clear any already saved dyes that were previously applied"

#### ClearTargetRoomComponent
- **Tainted**: No
- **Doc**: "Deselect the currently selected room component, if there is one"

#### CommitDyesForSelectedDecor
- **Tainted**: No
- **Doc**: "Attempt to save all previewed dye changes made to the selected decor"
- **Returns**: hasChanges (bool) — True if there were any changes to save

#### GetHoveredDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the placed decor instance currently being hovered, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetHoveredRoomComponentInfo
- **Tainted**: No
- **Doc**: "Returns info for the room component currently being hovered, if there is one"
- **Returns**: info (HousingRoomComponentInstanceInfo, nilable)

#### GetNumDyesToRemoveOnSelectedDecor
- **Tainted**: No
- **Doc**: "If a dyeable decor instance is selected, returns how many dye slots would be cleared on applying all currently previewed dye changes"
- **Returns**: numDyesToRemove (number)

#### GetNumDyesToSpendOnSelectedDecor
- **Tainted**: No
- **Doc**: "If a dyeable decor instance is selected, returns how many dye items would be spent on applying all currently previewed dye changes"
- **Returns**: numDyesToSpend (number)

#### GetPreviewDyesOnSelectedDecor
- **Tainted**: No
- **Doc**: "If a dyeable decor instance is selected, returns info structs for each new/changed dye currently being previewed"
- **Returns**: previewDyes (table<PreviewDyeSlotInfo>)

#### GetRecentlyUsedDyes
- **Tainted**: No
- **Doc**: "Returns a list of ids for the dyes most recently applied by the player, if any"
- **Returns**: recentDyes (table<number>)

#### GetRecentlyUsedThemeSets
- **Tainted**: No
- **Doc**: "Returns a list of ids for the theme sets (aka styles) most recently applied by the player, if any"
- **Returns**: recentThemeSets (table<number>)

#### GetRecentlyUsedWallpapers
- **Tainted**: No
- **Doc**: "Returns a list of ids for the wallpapers most recently applied by the player, if any"
- **Returns**: recentWallpapers (table<number>)

#### GetSelectedDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the decor instance that's currently selected, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetSelectedRoomComponentInfo
- **Tainted**: No
- **Doc**: "Returns info for the currently selected room component, if there is one"
- **Returns**: info (HousingRoomComponentInstanceInfo, nilable)

#### GetThemeSetInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Returns the name of the specified theme set (aka style) if it exists"
- **Args**: themeSetID (number)
- **Returns**: name (string, nilable)

#### GetWallpapersForRoomComponentType
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Get all wallpapers (aka materials/textures) available for the selected room component type, if any"
- **Args**: type (HousingRoomComponentType)
- **Returns**: availableWallpapers (table<RoomComponentWallpaper>)

#### IsDecorSelected
- **Tainted**: No
- **Doc**: "Returns true if a decor instance is currently selected for customization"
- **Returns**: hasSelectedDecor (bool)

#### IsHouseExteriorDoorHovered
- **Tainted**: No
- **Doc**: "Returns true if the entry door of the house's exterior is currently being hovered"
- **Returns**: isHouseExteriorDoorHovered (bool)

#### IsHoveringDecor
- **Tainted**: No
- **Doc**: "Returns true if a placed decor instance is currently being hovered"
- **Returns**: isHoveringDecor (bool)

#### IsHoveringRoomComponent
- **Tainted**: No
- **Doc**: "Returns true if a room component is currently being hovered"
- **Returns**: isHovering (bool)

#### IsRoomComponentSelected
- **Tainted**: No
- **Doc**: "Returns true if a room component is currently selected for customization"
- **Returns**: hasSelectedComponent (bool)

#### RoomComponentSupportsVariant
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Check whether a specific room component supports a particular variant; What kind of id or enum 'variant' equates to is complicated, as it depends on the component type"
- **Args**: componentID (number), variant (number)
- **Returns**: variantSupported (bool)

#### SetRoomComponentCeilingType
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to set a specific ceiling component, within a specific room, to a specific new ceiling type"
- **Args**: roomGUID (WOWGUID), componentID (number), ceilingType (HousingRoomComponentCeilingType)

#### SetRoomComponentDoorType
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Attempt to set a specific door component, within a specific room, to a specific new door type"
- **Args**: roomGUID (WOWGUID), componentID (number), newDoortype (HousingRoomComponentDoorType)

### Enumerations

#### HousingCustomizeModeTargetType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Decor | 1 |  |
| RoomComponent | 2 |  |
| ExteriorHouse | 3 |  |

### Structures

#### HousingRoomComponentInstanceInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| roomGUID | WOWGUID | No |  |
| type | HousingRoomComponentType | No |  |
| componentID | number | No |  |
| canBeCustomized | bool | No |  |
| currentThemeSet | number | Yes |  |
| availableThemeSets | table<number> | No |  |
| currentWallpaper | number | Yes |  |
| currentRoomComponentTextureRecID | number | Yes |  |
| ceilingType | HousingRoomComponentCeilingType | No |  |
| doorType | HousingRoomComponentDoorType | No |  |

#### PreviewDyeSlotInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| dyeColorID | number | No |  |
| dyeSlotID | number | No |  |

#### RoomComponentWallpaper
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| name | cstring | No |  |
| roomComponentTextureRecID | number | No |  |

### Events

#### HOUSING_CUSTOMIZE_MODE_HOVERED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasHoveredTarget | bool | No |
| targetType | HousingCustomizeModeTargetType | No |

#### HOUSING_CUSTOMIZE_MODE_SELECTED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelectedTarget | bool | No |
| targetType | HousingCustomizeModeTargetType | No |

#### HOUSING_DECOR_CUSTOMIZATION_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| decorGUID | WOWGUID | No |

#### HOUSING_DECOR_DYE_FAILURE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| decorGUID | WOWGUID | No |
| housingResult | HousingResult | No |

#### HOUSING_ROOM_COMPONENT_CUSTOMIZATION_CHANGE_FAILED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| roomGUID | WOWGUID | No |
| componentID | number | No |
| housingResult | HousingResult | No |

#### HOUSING_ROOM_COMPONENT_CUSTOMIZATION_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| roomGUID | WOWGUID | No |
| componentID | number | No |

---
## HousingExpertModeUI (from HousingExpertModeUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingExpertMode
- **Environment**: All

### Functions

#### CancelActiveEditing
- **Tainted**: No
- **Doc**: "Cancels all in-progress editing of the selected target, which will reset any unsaved changes and deselect the active target; Will not reset any already-applied changes"

#### CommitDecorMovement
- **Tainted**: No
- **Doc**: "Attempt to save the changes made to the currently selected decor instance"

#### CommitHouseExteriorPosition
- **Tainted**: No
- **Doc**: "Attempt to save the changes made to the House Exterior's position within the plot"

#### GetHoveredDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the placed decor instance currently being hovered, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### GetPrecisionSubmode
- **Tainted**: No
- **Doc**: "Returns the currently active Expert submode, if there is one"
- **Returns**: activeSubMode (HousingPrecisionSubmode, nilable)

#### GetPrecisionSubmodeRestriction
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Returns the type of restriction currently active on the submode; Will return HousingExpertSubmodeRestriction:None if submode is not currently restricted"
- **Args**: subMode (HousingPrecisionSubmode)
- **Returns**: restriction (HousingExpertSubmodeRestriction)

#### GetSelectedDecorInfo
- **Tainted**: No
- **Doc**: "Returns info for the placed decor instance that's currently selected, if there is one"
- **Returns**: info (HousingDecorInstanceInfo, nilable)

#### IsDecorSelected
- **Tainted**: No
- **Doc**: "Returns true if a placed decor instance is currently selected"
- **Returns**: hasSelectedDecor (bool)

#### IsGridVisible
- **Tainted**: No
- **Returns**: gridVisible (bool)

#### IsHouseExteriorHovered
- **Tainted**: No
- **Doc**: "Returns true if the house's exterior is currently being hovered"
- **Returns**: isHouseExteriorHovered (bool)

#### IsHouseExteriorSelected
- **Tainted**: No
- **Doc**: "Returns true if the house's exterior is currently selected"
- **Returns**: isHouseExteriorSelected (bool)

#### IsHoveringDecor
- **Tainted**: No
- **Doc**: "Returns true if a placed decor instance is currently being hovered"
- **Returns**: isHoveringDecor (bool)

#### RemoveSelectedDecor
- **Tainted**: No
- **Doc**: "Attempt to return the currently selected decor instance back to the house chest"

#### ResetPrecisionChanges
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Reset the selected target's transform back to default values; This is NOT an undo, meaning it will completely reset the transform value to default, NOT just recently-made changes"
- **Args**: activeSubmodeOnly (bool) — If true, only transform values associated with the currently active submode with be reset (ex: in Scale submode, only target's scale will be reset); If false, all transform values will be reset

#### SelectNextRotationAxis
- **Tainted**: No
- **Doc**: "In the rotation submode, swaps the selected axis to the next available one, in order of X -> Y -> Z (wrapping back around to X again, etc); If no axis is selected, selects the first available one, also in that order"

#### SetGridVisible
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: gridVisible (bool)

#### SetPrecisionIncrementingActive
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Sets a specific type of incremental change active or inactive; Whilever that type is active and target stays selected, incremental changes of that type will continue to be made every frame"
- **Args**: incrementType (HousingIncrementType), active (bool)

#### SetPrecisionSubmode
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Activate a specific Expert submode"
- **Args**: subMode (HousingPrecisionSubmode)

### Enumerations

#### HousingExpertModeTargetType
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Decor | 1 |  |
| House | 2 |  |

#### HousingExpertSubmodeRestriction
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| NotInExpertMode | 1 |  |
| NoHouseExteriorScale | 2 |  |
| NoWMOScale | 3 |  |

#### HousingIncrementType
| Name | Value | Documentation |
|------|-------|---------------|
| Left | 1 |  |
| Right | 2 |  |
| Forward | 4 |  |
| Back | 8 |  |
| Up | 16 |  |
| Down | 32 |  |
| RotateLeft | 64 |  |
| RotateRight | 128 |  |
| ScaleUp | 256 |  |
| ScaleDown | 512 |  |

#### HousingPrecisionSubmode
| Name | Value | Documentation |
|------|-------|---------------|
| Translate | 0 |  |
| Rotate | 1 |  |
| Scale | 2 |  |

### Events

#### HOUSING_DECOR_PRECISION_MANIPULATION_EVENT
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| event | TransformManipulatorEvent | No |

#### HOUSING_DECOR_PRECISION_MANIPULATION_STATUS_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| isManipulatingSelection | bool | No |

#### HOUSING_DECOR_PRECISION_SUBMODE_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| activeSubmode | HousingPrecisionSubmode | Yes |

#### HOUSING_EXPERT_MODE_HOVERED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasHoveredTarget | bool | No |
| targetType | HousingExpertModeTargetType | No |

#### HOUSING_EXPERT_MODE_PLACEMENT_FLAGS_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| targetType | HousingExpertModeTargetType | No |
| activeFlags | HousingDecorPlacementRestriction | No |

#### HOUSING_EXPERT_MODE_SELECTED_TARGET_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelectedTarget | bool | No |
| targetType | HousingExpertModeTargetType | No |

---
## HousingNeighborhoodUI (from HousingNeighborhoodUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HousingNeighborhood
- **Environment**: All

### Functions

#### CanReturnAfterVisitingHouse
- **Tainted**: No
- **Returns**: canReturn (bool)

#### CancelInviteToNeighborhood
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Only available when interacting with a bulletin board game object"
- **Args**: playerName (cstring)

#### DemoteToResident
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Only available when interacting with a bulletin board game object"
- **Args**: playerGUID (WOWGUID)

#### GetCornerstoneHouseInfo
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: houseInfo (HouseInfo)

#### GetCornerstoneNeighborhoodInfo
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: neighborhoodInfo (NeighborhoodInfo)

#### GetCornerstonePurchaseMode
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: purchaseMode (CornerstonePurchaseMode)

#### GetCurrentNeighborhoodTextureSuffix
- **Tainted**: No
- **Returns**: neighborhoodTextureSuffix (cstring)

#### GetDiscountedMovePrice
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: movePrice (number) — Can be negative if the refund from moving is more than the cost of the new house

#### GetMoveCooldownTime
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: movecooldownTime (number)

#### GetNeighborhoodMapData
- **Tainted**: No
- **Returns**: neighborhoodPlots (table<NeighborhoodPlotMapInfo>)

#### GetNeighborhoodName
- **Tainted**: No
- **Returns**: neighborhoodName (string)

#### GetNeighborhoodPlotName
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: plotIndex (number)
- **Returns**: neighborhoodName (string)

#### GetPreviousHouseIdentifier
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: previousHouseIdentifier (string)

#### HasPermissionToPurchase
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: cantPurchaseReason (PurchaseHouseDisabledReason)

#### InvitePlayerToNeighborhood
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Only available when interacting with a bulletin board game object"
- **Args**: playerName (cstring)

#### IsNeighborhoodManager
- **Tainted**: No
- **Returns**: isManager (bool)

#### IsNeighborhoodOwner
- **Tainted**: No
- **Returns**: isOwner (bool)

#### IsPlayerInOtherPlayersPlot
- **Tainted**: No
- **Doc**: "This returns true if the player is in a plot that is owned by another player"
- **Returns**: isInUnownedPlot (bool)

#### IsPlotAvailableForPurchase
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: isAvailable (bool)

#### IsPlotOwnedByPlayer
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"
- **Returns**: isPlayerOwned (bool)

#### OnBulletinBoardClosed
- **Tainted**: No

#### PromoteToManager
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Only available when interacting with a bulletin board game object"
- **Args**: playerGUID (WOWGUID)

#### RequestNeighborhoodInfo
- **Tainted**: No

#### RequestNeighborhoodRoster
- **Tainted**: No
- **Doc**: "Only available when interacting with a bulletin board game object"

#### RequestPendingNeighborhoodInvites
- **Tainted**: No
- **Doc**: "Only available when interacting with a bulletin board game object"

#### TransferNeighborhoodOwnership
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Only available when interacting with a bulletin board game object"
- **Args**: playerGUID (WOWGUID)

#### TryEvictPlayer
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Only available when interacting with a bulletin board game object"
- **Args**: plotID (number)

#### TryMoveHouse
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"

#### TryPurchasePlot
- **Tainted**: No
- **Doc**: "Only available when interacting with a cornerstone game object"

### Enumerations

#### CornerstonePurchaseMode
| Name | Value | Documentation |
|------|-------|---------------|
| Basic | 0 |  |
| Import | 1 |  |
| Move | 2 |  |

### Events

#### CANCEL_NEIGHBORHOOD_INVITE_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | NeighborhoodInviteResult | No |
| playerName | cstring | Yes |

#### CLOSE_PLOT_CORNERSTONE
*SynchronousEvent*

#### NEIGHBORHOOD_INFO_UPDATED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodInfo | NeighborhoodInfo | No |

#### NEIGHBORHOOD_INVITE_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | NeighborhoodInviteResult | No |

#### NEIGHBORHOOD_MAP_DATA_UPDATED
*UniqueEvent*

#### NEIGHBORHOOD_NAME_UPDATED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodGuid | WOWGUID | No |
| neighborhoodName | cstring | No |

#### OPEN_PLOT_CORNERSTONE
*SynchronousEvent*

#### PENDING_NEIGHBORHOOD_INVITES_RECIEVED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | NeighborhoodInviteResult | No |
| pendingInviteList | table<string> | Yes |

#### PURCHASE_PLOT_RESULT
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | number | No |

#### SHOW_PLAYER_EVICTED_DIALOG
*SynchronousEvent*

#### UPDATE_BULLETIN_BOARD_MEMBER_TYPE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| player | WOWGUID | No |
| residentType | ResidentType | No |

#### UPDATE_BULLETIN_BOARD_ROSTER
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| neighborhoodInfo | NeighborhoodInfo | No |
| rosterMemberList | table<NeighborhoodRosterMemberInfo> | No |

#### UPDATE_BULLETIN_BOARD_ROSTER_STATUSES
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| rosterMemberList | table<NeighborhoodRosterMemberUpdateInfo> | No |

---
## HouseExteriorUI (from HouseExteriorUIDocumentation.lua)
- **Type**: System
- **Namespace**: C_HouseExterior
- **Environment**: All

### Functions

#### CancelActiveExteriorEditing
- **Tainted**: No
- **Doc**: "Cancels all in-progress editing of house exterior fixtures, which will deselect any active targets"

#### GetCoreFixtureOptionsInfo
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: coreFixtureType (HousingFixtureType)
- **Returns**: coreFixtureOptionsInfo (HousingCoreFixtureInfo, nilable)

#### GetCurrentHouseExteriorSize
- **Tainted**: No
- **Returns**: houseExteriorSize (HousingFixtureSize, nilable)

#### GetCurrentHouseExteriorType
- **Tainted**: No
- **Returns**: houseExteriorTypeID (number, nilable), houseExteriorTypeName (cstring, nilable)

#### GetHouseExteriorSizeOptions
- **Tainted**: No
- **Returns**: options (HouseExteriorSizeOptionsInfo, nilable)

#### GetHouseExteriorTypeOptions
- **Tainted**: No
- **Returns**: options (HouseExteriorTypeOptionsInfo, nilable)

#### GetSelectedFixturePointInfo
- **Tainted**: No
- **Returns**: fixturePointInfo (HousingFixturePointInfo, nilable)

#### HasHoveredFixture
- **Tainted**: No
- **Returns**: anyHoveredFixture (bool)

#### HasSelectedFixturePoint
- **Tainted**: No
- **Returns**: anySelectedFixturePoint (bool)

#### RemoveFixtureFromSelectedPoint
- **Tainted**: No

#### SelectCoreFixtureOption
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: fixtureID (number)

#### SelectFixtureOption
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: fixtureID (number)

#### SetHouseExteriorSize
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: size (HousingFixtureSize)

#### SetHouseExteriorType
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: houseExteriorTypeID (number)

### Events

#### HOUSE_EXTERIOR_TYPE_UNLOCKED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| fixtureID | number | No |

#### HOUSING_CORE_FIXTURE_CHANGED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| coreFixtureType | HousingFixtureType | No |

#### HOUSING_FIXTURE_HOVER_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| anyHovered | bool | No |

#### HOUSING_FIXTURE_POINT_FRAME_ADDED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| pointFrame | HousingFixturePointFrame | No |

#### HOUSING_FIXTURE_POINT_FRAME_RELEASED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| pointFrame | HousingFixturePointFrame | No |

#### HOUSING_FIXTURE_POINT_FRAMES_RELEASED
*SynchronousEvent*

#### HOUSING_FIXTURE_POINT_SELECTION_CHANGED
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| hasSelection | bool | No |

#### HOUSING_FIXTURE_UNLOCKED
*UniqueEvent*

| Field | Type | Nilable |
|-------|------|---------|
| fixtureID | number | No |

#### HOUSING_SET_EXTERIOR_HOUSE_SIZE_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |

#### HOUSING_SET_EXTERIOR_HOUSE_TYPE_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |

#### HOUSING_SET_FIXTURE_RESPONSE
*SynchronousEvent*

| Field | Type | Nilable |
|-------|------|---------|
| result | HousingResult | No |

---
## HouseExteriorConstantsDocumentation (from HouseExteriorConstantsDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Structures

#### HouseExteriorSizeOption
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| size | HousingFixtureSize | No |  |
| name | cstring | No |  |
| isLocked | bool | No |  |

#### HouseExteriorSizeOptionsInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| selectedSize | HousingFixtureSize | No |  |
| options | table<HouseExteriorSizeOption> | No |  |

#### HouseExteriorTypeOption
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| houseExteriorTypeID | number | No |  |
| name | cstring | No |  |
| isLocked | bool | No |  |
| lockReasonString | cstring | No |  |

#### HouseExteriorTypeOptionsInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| selectedExteriorType | number | No |  |
| options | table<HouseExteriorTypeOption> | No |  |

#### HousingCoreFixtureInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| selectedVariantFixtureID | number | No | For fixtures that are variants, the id of specific selected variant; If fixture has no variants, will be the same id as selectedStyleFixtureID |
| selectedStyleFixtureID | number | No | For fixtures that are variants, the id of their specific base style fixture; If fixture has no variants, will be the same id as selectedVariantFixtureID |
| currentStyleVariantOptions | table<HousingFixtureOption> | No | Fixtures that are variants of the same style as the selected (meaning they all share the same hooks); Includes the currently selected fixture |
| styleOptions | table<HousingFixtureOption> | No | Fixtures that are different styles for this type and size of fixture (swapping will clear all hooks); Includes the currently selected fixture |

#### HousingFixtureOption
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| fixtureID | number | No |  |
| name | cstring | No |  |
| typeID | number | No |  |
| typeName | cstring | No |  |
| isLocked | bool | No |  |
| lockReasonString | cstring | No |  |
| colorID | number | No |  |

#### HousingFixturePointInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| ownerHash | number | No |  |
| selectedFixtureID | number | Yes |  |
| fixtureOptions | table<HousingFixtureOption> | No |  |
| canSelectionBeRemoved | bool | No |  |

---
## HousingCatalogConstantsDocumentation (from HousingCatalogConstantsDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Enumerations

#### HousingCatalogEntryModelScenePresets
| Name | Value | Documentation |
|------|-------|---------------|
| DecorDefault | 1317 |  |
| DecorTiny | 1333 |  |
| DecorSmall | 1334 |  |
| DecorMedium | 1335 |  |
| DecorLarge | 1336 |  |
| DecorHuge | 1337 |  |
| DecorCeiling | 1338 |  |
| DecorWall | 1339 |  |
| DecorFlat | 1318 |  |

#### HousingCatalogEntrySize
| Name | Value | Documentation |
|------|-------|---------------|
| None | 0 |  |
| Tiny | 65 |  |
| Small | 66 |  |
| Medium | 67 |  |
| Large | 68 |  |
| Huge | 69 |  |

#### HousingCatalogEntrySubtype
| Name | Value | Documentation |
|------|-------|---------------|
| Invalid | 0 |  |
| Unowned | 1 | Unowned entry, for displaying a catalog object in a static context |
| OwnedModifiedStack | 2 | Stack of owned instances that share specific modifications (ex: stack of red-dyed chairs) |
| OwnedUnmodifiedStack | 3 | Stack of owned default instances of a record |

#### HousingCatalogEntryType
| Name | Value | Documentation |
|------|-------|---------------|
| Invalid | 0 |  |
| Decor | 1 |  |
| Room | 2 |  |

#### HousingCatalogSortType
| Name | Value | Documentation |
|------|-------|---------------|
| DateAdded | 0 |  |
| Alphabetical | 1 |  |

### Structures

#### HousingCatalogEntryID
*Compound Identifier for entry stacks in the catalog*

| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| recordID | number | No |  |
| entryType | HousingCatalogEntryType | No |  |
| entrySubtype | HousingCatalogEntrySubtype | No |  |
| subtypeIdentifier | number | No | Hashed value used to identify and differentiate stacks that are the same type and subtype, but have some other subtype-specific difference |

#### HousingCatalogFilterTagGroupInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| groupID | number | No |  |
| groupName | cstring | No |  |
| tags | table<HousingCatalogFilterTagInfo> | No |  |

#### HousingCatalogFilterTagInfo
| Field | Type | Nilable | Documentation |
|-------|------|---------|---------------|
| tagID | number | No |  |
| tagName | string | No |  |
| orderIndex | number | No |  |
| anyAssociatedEntries | bool | No |  |

### Constants

#### HousingCatalogConsts
| Name | Type | Value |
|------|------|-------|

---
## HousingCatalogSearcherAPI (from HousingCatalogSearcherAPIDocumentation.lua)
- **Type**: ScriptObject
- **Environment**: All

### Functions

#### GetAllSearchItems
- **Tainted**: No
- **Doc**: "Returns all catalog entries being searched (note these are NOT search results, this is the source collection of what's being searched)"
- **Returns**: matchingEntryIDs (table<HousingCatalogEntryID>)

#### GetCatalogSearchResults
- **Tainted**: No
- **Doc**: "Returns the most recent search result entries"
- **Returns**: matchingEntryIDs (table<HousingCatalogEntryID>)

#### GetEditorModeContext
- **Tainted**: No
- **Returns**: editorModeContext (HouseEditorMode, nilable)

#### GetFilterTagStatus
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: groupID (number), tagID (number)
- **Returns**: active (bool)

#### GetFilteredCategoryID
- **Tainted**: No
- **Returns**: categoryID (number, nilable)

#### GetFilteredSubcategoryID
- **Tainted**: No
- **Returns**: subcategoryID (number, nilable)

#### GetNumSearchItems
- **Tainted**: No
- **Doc**: "Returns the total number of entries being searched through"
- **Returns**: numSearchItems (number)

#### GetSearchCount
- **Tainted**: No
- **Doc**: "Returns the total number of owned instances across all most recent search result entries"
- **Returns**: searchCount (number)

#### GetSearchText
- **Tainted**: No
- **Returns**: searchText (string, nilable)

#### GetSortType
- **Tainted**: No
- **Returns**: sortType (HousingCatalogSortType)

#### IsAllowedIndoorsActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### IsAllowedOutdoorsActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### IsCollectedActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### IsCustomizableOnlyActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### IsFirstAcquisitionBonusOnlyActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### IsOwnedOnlyActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### IsSearchInProgress
- **Tainted**: No
- **Returns**: isSearchInProgress (bool)

#### IsUncollectedActive
- **Tainted**: No
- **Returns**: isActive (bool)

#### RunSearch
- **Tainted**: No
- **Doc**: "Run search with all current param values"

#### SetAllInFilterTagGroup
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Set the toggle state of all filter tags within a specific group; If active, only entries that match Any of the tags in the group will be included in search results"
- **Args**: groupID (number), active (bool)

#### SetAllowedIndoors
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, entries that can be placed in house interiors will be included in the search; Note many decor objects can be placed both indoors and outdoors, so having only this toggled on may still include decor that can also be placed outdoors"
- **Args**: isActive (bool)

#### SetAllowedOutdoors
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, entries that can be placed outside in plots will be included in the search; Note many decor objects can be placed both indoors and outdoors, so having only this toggled on may still include decor that can also be placed indoors"
- **Args**: isActive (bool)

#### SetAutoUpdateOnParamChanges
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "If true, searcher automatically updates results whenever search param values are changed"
- **Args**: autoUpdateActive (bool)

#### SetCollected
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, includes all owned entries, including those that are in storage OR placed in an owned house or plot; See IsOwnedOnlyActive for a more exclusive toggle"
- **Args**: isActive (bool)

#### SetCustomizableOnly
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, catalog entries that cannot be customized (ie dyed) will be excluded from the search"
- **Args**: isActive (bool)

#### SetEditorModeContext
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If set, limits search results to only entries that are used/valid in the specified editor mode"
- **Args**: editorModeContext (HouseEditorMode, nilable)

#### SetFilterTagStatus
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Set the toggle state of a single filter tag within a specific group"
- **Args**: groupID (number), tagID (number), active (bool)

#### SetFilteredCategoryID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If set, limits search results to only those within the specified category"
- **Args**: categoryID (number, nilable)

#### SetFilteredSubcategoryID
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If set, limits search results to only those within the specified subcategory"
- **Args**: subcategoryID (number, nilable)

#### SetFirstAcquisitionBonusOnly
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, excludes any entries that do not reward house xp when acquired for the first time"
- **Args**: isActive (bool)

#### SetOwnedOnly
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, only entries that you own, and have instances of available in storage, will be included; This does not include entries that you own but have all been placed in a house; See IsCollectedActive for param that includes placed entries"
- **Args**: isActive (bool)

#### SetResultsUpdatedCallback
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: callback (HousingCatalogSearchResultsUpdatedCallback)

#### SetSearchText
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If set, multiple text fields are checked for instances of the text, including name, category, subcategory, and data tags"
- **Args**: searchText (string, nilable) — Supports advanced search tokens ('\"' '-' and '|'), case and accent insensitive; Set nil to clear out the search text

#### SetSortType
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: sortType (HousingCatalogSortType)

#### SetUncollected
- **Tainted**: Yes (AllowedWhenUntainted)
- **Doc**: "Search parameter; If true, includes entries that are not owned, meaning not available in storage nor placed in any owned houses or plots"
- **Args**: isActive (bool)

#### ToggleAllowedIndoors
- **Tainted**: No

#### ToggleAllowedOutdoors
- **Tainted**: No

#### ToggleCollected
- **Tainted**: No

#### ToggleCustomizableOnly
- **Tainted**: No

#### ToggleFilterTag
- **Tainted**: Yes (AllowedWhenUntainted)
- **Args**: groupID (number), tagID (number)

#### ToggleFirstAcquisitionBonusOnly
- **Tainted**: No

#### ToggleOwnedOnly
- **Tainted**: No

#### ToggleUncollected
- **Tainted**: No

### Callback Types

- **HousingCatalogSearchResultsUpdatedCallback**

---
## NeighborhoodInitiativesConstantsDocumentation (from NeighborhoodInitiativesConstantsDocumentation.lua)
- **Type**: Unknown
- **Environment**: All

### Enumerations

#### InitiativeMilestoneFlags
| Name | Value | Documentation |
|------|-------|---------------|
| FinalMilestone | 1 |  |

#### InitiativeRewardFlags
| Name | Value | Documentation |
|------|-------|---------------|
| PermanentWorldState | 1 |  |

#### NeighborhoodInitiativeChestResult
| Name | Value | Documentation |
|------|-------|---------------|
| NiSuccess | 0 |  |
| NiUnspecifiedFailure | 1 |  |
| NiNoHouseFound | 2 |  |
| NiNoRewards | 3 |  |
| NiThrottled | 4 |  |
| NiServiceDisabled | 5 |  |

#### NeighborhoodInitiativeFlags
| Name | Value | Documentation |
|------|-------|---------------|
| Disabled | 1 |  |
| NoAbandon | 2 |  |
| NoRepeat | 4 |  |

#### NeighborhoodInitiativeNeighborhoodTypes
| Name | Value | Documentation |
|------|-------|---------------|
| NiNeighborhoodTypeSingleton | 0 |  |
| NiNeighborhoodTypePool | 1 |  |

#### NeighborhoodInitiativeTaskType
| Name | Value | Documentation |
|------|-------|---------------|
| Single | 0 |  |
| RepeatableFinite | 1 |  |
| RepeatableInfinite | 2 |  |

#### NeighborhoodInitiativeUpdateStatus
| Name | Value | Documentation |
|------|-------|---------------|
| Started | 0 |  |
| MilestoneCompleted | 1 |  |
| Completed | 2 |  |
| Failed | 3 |  |

#### NeighborhoodInitiativesCompletionStates
| Name | Value | Documentation |
|------|-------|---------------|
| NiCompletionStateNotCompleted | 0 |  |
| NiCompletionStatePlayerCompleted | 1 |  |
| NiCompletionStateSystemAbandoned | 2 |  |

---
# Homestead Addon Analysis

## Key Findings

### 1. Full Catalog Enumeration

**Can we enumerate ALL decor items (including unowned) programmatically?**

**YES** - The `HousingCatalogSearcherAPI` ScriptObject provides comprehensive enumeration:

- `CreateCatalogSearcher()` (C_HousingCatalog) — Creates a new searcher instance (NO taint restriction)
- `SetUncollected(isActive)` — Include unowned items in search (tainted: AllowedWhenUntainted)
- `SetCollected(isActive)` — Include owned items in search (tainted)
- `RunSearch()` — Execute the search (NO taint restriction)
- `GetCatalogSearchResults()` — Get matching entry IDs (NO taint restriction)
- `GetAllSearchItems()` — Get ALL items being searched, not just results (NO taint restriction)

**Critical insight**: The Searcher's getter functions (`GetCatalogSearchResults`, `GetAllSearchItems`, 
`IsUncollectedActive`, etc.) are NOT tainted, only the setters are. This means:
1. Blizzard's UI sets up the searcher (calls SetUncollected, etc.)
2. Addon code can READ the results without taint issues

**However**: `GetCatalogEntryInfo()` and related functions ARE tainted, so getting detailed 
info about the entries returned by the searcher may still require UI interaction.

### 2. Source/Vendor Data

**Can we get source or vendor information for items we don't own?**

**NO** - The API does NOT provide source/vendor information. Key structures examined:

- `HousingCatalogEntryInfo` — Contains: entryID, entryType, entrySubtype, recordID, 
  quantity fields, categoryID, subcategoryID. **NO source field**.
- `HousingDecorInstanceInfo` — Instance info for placed decor. **NO source field**.
- `HousingPreviewItemData` — Preview data. **NO vendor/source field**.

**Conclusion**: Vendor/source mapping must come from external data (Wowhead scraping, 
manual database like DecorSources.lua) or in-game vendor scanning.

### 3. Taint Blockers

**Which useful functions have SecretArguments restrictions?**

Most C_HousingCatalog functions are tainted with `AllowedWhenUntainted`. This means:
- They work when called from Blizzard UI code
- They fail/error when called from addon code (tainted execution)

**Critical tainted functions for Homestead:**
- `GetCatalogEntryInfo(entryID)` — Can't get item details from addon code
- `GetCatalogEntryInfoByItem(itemInfo, tryGetOwnedInfo)` — Can't lookup by item link
- `GetCatalogEntryInfoByRecordID(type, recordID, tryGetOwnedInfo)` — Can't lookup by ID
- `GetCatalogCategoryInfo(categoryID)` — Can't get category names
- `GetCatalogSubcategoryInfo(subcategoryID)` — Can't get subcategory names

**Untainted functions (addon-usable):**
- `CreateCatalogSearcher()` — Can create searcher instances!
- `GetAllFilterTagGroups()` — Can get filter tag info
- `GetCartSizeLimit()` — Cart limit
- `GetDecorMaxOwnedCount()` / `GetDecorTotalOwnedCount()` — Ownership counts
- Searcher instance getters: `GetCatalogSearchResults()`, `GetAllSearchItems()`, etc.

**Can addon code realistically use the SearcherAPI?**

**Partially**. Addon can:
1. Create a searcher via `C_HousingCatalog.CreateCatalogSearcher()`
2. Call `RunSearch()` (untainted)
3. Call `GetCatalogSearchResults()` to get entry IDs (untainted)

Addon **cannot** directly:
- Call `SetUncollected()`, `SetCollected()`, etc. (tainted)
- Call `GetCatalogEntryInfo()` to get details about entries (tainted)

**Workaround potential**: If the player opens the Housing Catalog UI with 
"Show Uncollected" enabled, the addon might be able to read the results 
from that searcher state.

### 4. Missing Events

**Are there housing events we should be listening to?**

Key events from the documentation:

**Catalog/Storage Events:**
- `HOUSING_CATALOG_CATEGORY_UPDATED` — Category changed
- `HOUSING_CATALOG_SUBCATEGORY_UPDATED` — Subcategory changed
- `HOUSING_STORAGE_UPDATED` — Storage changed (UniqueEvent)
- `HOUSING_STORAGE_ENTRY_UPDATED` — Specific entry changed
- `HOUSING_REFUND_LIST_UPDATED` — Refund list changed

**Preview/Cart Events:**
- `HOUSING_DECOR_ADD_TO_PREVIEW_LIST` — Item added to preview
- `HOUSING_DECOR_PREVIEW_LIST_UPDATED` — Preview list changed
- `HOUSING_DECOR_PREVIEW_LIST_REMOVE_FROM_WORLD` — Preview item removed

**Layout/Editor Events:**
- `HOUSING_LAYOUT_ENTER_EDIT_MODE` — Entered edit mode
- `HOUSING_LAYOUT_EXIT_EDIT_MODE` — Exited edit mode
- `HOUSING_LAYOUT_DECOR_PLACED` — Decor placed in world
- `HOUSING_LAYOUT_DECOR_RETURNED_TO_STORAGE` — Decor returned to storage
- `HOUSING_LAYOUT_DECOR_SELECTED` / `DESELECTED` — Selection changed

**Recommended additions for Homestead:**
- `HOUSING_STORAGE_UPDATED` — Refresh ownership cache when storage changes
- `HOUSING_STORAGE_ENTRY_UPDATED` — Update specific entry in cache
- `HOUSING_LAYOUT_DECOR_PLACED` / `RETURNED_TO_STORAGE` — Track placement changes

### 5. Item-to-Vendor Mapping

**Is there any API path from item/recordID to vendor/merchant data?**

**NO** - There is no connection between Housing APIs and Merchant APIs.

The `C_MerchantFrame` API provides:
- `GetMerchantItemInfo(index)` — Returns: name, texture, price, stackCount, etc.
- `GetMerchantItemLink(index)` — Returns item link
- `GetMerchantItemID(index)` — Returns itemID

But there's no:
- API to query "which vendors sell this item"
- Connection from `HousingCatalogEntryInfo` to merchant data
- Source field in any housing structure

**Conclusion**: Vendor scanning remains necessary. The API does not provide 
any vendor/source information for decor items.

### 6. Unowned Item Data

**What data fields are available for items the player doesn't own?**

From `HousingCatalogEntryInfo` structure:

| Field | Available for Unowned? | Notes |
|-------|------------------------|-------|
| entryID | Yes | HousingCatalogEntryID |
| entryType | Yes | HousingCatalogEntryType enum |
| entrySubtype | **No** | 1 = Unowned, other values = owned variants |
| recordID | Yes | Internal record ID |
| totalQuantity | No | Only for owned |
| availableQuantity | No | Only for owned |
| placedQuantity | No | Only for owned |
| categoryID | Yes | Category reference |
| subcategoryID | Yes | Subcategory reference |

**Note**: Getting the actual item **name** and **icon** requires calling 
`GetCatalogEntryInfo()` which is tainted. The entry ID alone doesn't provide display info.

### 7. Market Cart / Merchant Integration

**Do HousingMarketCart or MerchantFrame APIs reveal vendor-decor relationships?**

**No direct relationship.** Analysis:

- `HousingMarketCartInfo` structure exists but relates to the in-game housing market 
  (player housing shop), not vendors
- `C_MerchantFrame` API is generic for all merchants, not housing-specific
- No API connects merchant NPCs to decor items

The housing "Market Cart" is separate from NPC vendors — it's the shopping cart 
in the Housing Catalog UI for purchasing from the in-game shop.

### 8. Searcher Instance

**How is the HousingCatalogSearcherAPI ScriptObject instantiated?**

```lua
-- Create a new searcher instance
local searcher = C_HousingCatalog.CreateCatalogSearcher()

-- The searcher is a ScriptObject with methods like:
searcher:SetUncollected(true)     -- TAINTED
searcher:SetCollected(true)       -- TAINTED
searcher:RunSearch()              -- Untainted
local results = searcher:GetCatalogSearchResults()  -- Untainted
```

**Can addons create or access one?**

**Yes**, `CreateCatalogSearcher()` is NOT tainted. Addons can create instances.

**However**, the configuration methods (`SetUncollected`, `SetCollected`, etc.) ARE 
tainted, so the addon-created searcher would have default filter settings.

**Potential workaround**: Hook into Blizzard's Housing Catalog frame to access 
their pre-configured searcher instance.

## Taint Summary

All functions with `SecretArguments = "AllowedWhenUntainted"`:

### AllowedWhenUntainted

- `C_DyeColor.GetAllDyeColors`
- `C_DyeColor.GetDyeColorCategoryInfo`
- `C_DyeColor.GetDyeColorForItem`
- `C_DyeColor.GetDyeColorForItemLocation`
- `C_DyeColor.GetDyeColorInfo`
- `C_DyeColor.GetDyeColorsInCategory`
- `C_DyeColor.IsDyeColorOwned`
- `C_HouseEditor.ActivateHouseEditorMode`
- `C_HouseEditor.GetHouseEditorModeAvailability`
- `C_HouseEditor.IsHouseEditorModeActive`
- `C_HouseExterior.GetCoreFixtureOptionsInfo`
- `C_HouseExterior.SelectCoreFixtureOption`
- `C_HouseExterior.SelectFixtureOption`
- `C_HouseExterior.SetHouseExteriorSize`
- `C_HouseExterior.SetHouseExteriorType`
- `C_Housing.CanTakeReportScreenshot`
- `C_Housing.CreateGuildNeighborhood`
- `C_Housing.CreateNeighborhoodCharter`
- `C_Housing.DoesFactionMatchNeighborhood`
- `C_Housing.EditNeighborhoodCharter`
- `C_Housing.GetCurrentHouseLevelFavor`
- `C_Housing.GetHouseLevelFavorForLevel`
- `C_Housing.GetHouseLevelRewardsForLevel`
- `C_Housing.GetNeighborhoodTextureSuffix`
- `C_Housing.GetOthersOwnedHouses`
- `C_Housing.GetUIMapIDForNeighborhood`
- `C_Housing.HouseFinderRequestReservationAndPort`
- `C_Housing.OnHouseFinderClickPlot`
- `C_Housing.OnSignCharterClicked`
- `C_Housing.RelinquishHouse`
- `C_Housing.RequestHouseFinderNeighborhoodData`
- `C_Housing.SaveHouseSettings`
- `C_Housing.SearchBNetFriendNeighborhoods`
- `C_Housing.SearchBNetFriendNeighborhoodsByID`
- `C_Housing.SetTrackedHouseGuid`
- `C_Housing.TeleportHome`
- `C_Housing.TryRenameNeighborhood`
- `C_Housing.ValidateNeighborhoodName`
- `C_Housing.VisitHouse`
- `C_HousingBasicMode.RotateDecor`
- `C_HousingBasicMode.RotateHouseExterior`
- `C_HousingBasicMode.SetFreePlaceEnabled`
- `C_HousingBasicMode.SetGridSnapEnabled`
- `C_HousingBasicMode.SetGridVisible`
- `C_HousingBasicMode.StartPlacingNewDecor`
- `C_HousingBasicMode.StartPlacingPreviewDecor`
- `C_HousingCatalog.CanDestroyEntry`
- `C_HousingCatalog.DeletePreviewCartDecor`
- `C_HousingCatalog.DestroyEntry`
- `C_HousingCatalog.GetBundleInfo`
- `C_HousingCatalog.GetCatalogCategoryInfo`
- `C_HousingCatalog.GetCatalogEntryInfo`
- `C_HousingCatalog.GetCatalogEntryInfoByItem`
- `C_HousingCatalog.GetCatalogEntryInfoByRecordID`
- `C_HousingCatalog.GetCatalogEntryRefundTimeStampByRecordID`
- `C_HousingCatalog.GetCatalogSubcategoryInfo`
- `C_HousingCatalog.IsPreviewCartItemShown`
- `C_HousingCatalog.PromotePreviewDecor`
- `C_HousingCatalog.SearchCatalogCategories`
- `C_HousingCatalog.SearchCatalogSubcategories`
- `C_HousingCatalog.SetPreviewCartItemShown`
- `C_HousingCustomizeMode.ApplyDyeToSelectedDecor`
- `C_HousingCustomizeMode.ApplyThemeToRoom`
- `C_HousingCustomizeMode.ApplyThemeToSelectedRoomComponent`
- `C_HousingCustomizeMode.ApplyWallpaperToAllWalls`
- `C_HousingCustomizeMode.ApplyWallpaperToSelectedRoomComponent`
- `C_HousingCustomizeMode.GetThemeSetInfo`
- `C_HousingCustomizeMode.GetWallpapersForRoomComponentType`
- `C_HousingCustomizeMode.RoomComponentSupportsVariant`
- `C_HousingCustomizeMode.SetRoomComponentCeilingType`
- `C_HousingCustomizeMode.SetRoomComponentDoorType`
- `C_HousingDecor.GetDecorIcon`
- `C_HousingDecor.GetDecorInstanceInfoForGUID`
- `C_HousingDecor.GetDecorName`
- `C_HousingDecor.IsModeDisabledForPreviewState`
- `C_HousingDecor.RemovePlacedDecorEntry`
- `C_HousingDecor.SetGridVisible`
- `C_HousingDecor.SetPlacedDecorEntryHovered`
- `C_HousingDecor.SetPlacedDecorEntrySelected`
- `C_HousingExpertMode.GetPrecisionSubmodeRestriction`
- `C_HousingExpertMode.ResetPrecisionChanges`
- `C_HousingExpertMode.SetGridVisible`
- `C_HousingExpertMode.SetPrecisionIncrementingActive`
- `C_HousingExpertMode.SetPrecisionSubmode`
- `C_HousingLayout.AnyRoomsOnFloor`
- `C_HousingLayout.ConfirmStairChoice`
- `C_HousingLayout.HasStairs`
- `C_HousingLayout.HasValidConnection`
- `C_HousingLayout.IsBaseRoom`
- `C_HousingLayout.MoveDraggedRoom`
- `C_HousingLayout.MoveLayoutCamera`
- `C_HousingLayout.RemoveRoom`
- `C_HousingLayout.RotateFocusedRoom`
- `C_HousingLayout.RotateRoom`
- `C_HousingLayout.SelectFloorplan`
- `C_HousingLayout.SetViewedFloor`
- `C_HousingLayout.ZoomLayoutCamera`
- `C_HousingNeighborhood.CancelInviteToNeighborhood`
- `C_HousingNeighborhood.DemoteToResident`
- `C_HousingNeighborhood.GetNeighborhoodPlotName`
- `C_HousingNeighborhood.InvitePlayerToNeighborhood`
- `C_HousingNeighborhood.PromoteToManager`
- `C_HousingNeighborhood.TransferNeighborhoodOwnership`
- `C_HousingNeighborhood.TryEvictPlayer`
- `C_MerchantFrame.GetBuybackItemID`
- `C_MerchantFrame.GetItemInfo`
- `C_MerchantFrame.IsMerchantItemRefundable`
- `HousingCatalogSearcherAPI.GetFilterTagStatus`
- `HousingCatalogSearcherAPI.SetAllInFilterTagGroup`
- `HousingCatalogSearcherAPI.SetAllowedIndoors`
- `HousingCatalogSearcherAPI.SetAllowedOutdoors`
- `HousingCatalogSearcherAPI.SetAutoUpdateOnParamChanges`
- `HousingCatalogSearcherAPI.SetCollected`
- `HousingCatalogSearcherAPI.SetCustomizableOnly`
- `HousingCatalogSearcherAPI.SetEditorModeContext`
- `HousingCatalogSearcherAPI.SetFilterTagStatus`
- `HousingCatalogSearcherAPI.SetFilteredCategoryID`
- `HousingCatalogSearcherAPI.SetFilteredSubcategoryID`
- `HousingCatalogSearcherAPI.SetFirstAcquisitionBonusOnly`
- `HousingCatalogSearcherAPI.SetOwnedOnly`
- `HousingCatalogSearcherAPI.SetResultsUpdatedCallback`
- `HousingCatalogSearcherAPI.SetSearchText`
- `HousingCatalogSearcherAPI.SetSortType`
- `HousingCatalogSearcherAPI.SetUncollected`
- `HousingCatalogSearcherAPI.ToggleFilterTag`
- `HousingFixturePointFrameAPI.SetUpdateCallback`
- `HousingLayoutPinFrameAPI.Drag`
- `HousingLayoutPinFrameAPI.SetUpdateCallback`

## Type Cross-Reference

### What returns HousingCatalogEntryID?
- `HousingCatalogSearcher:GetCatalogSearchResults()` — Returns table<HousingCatalogEntryID>
- `HousingCatalogSearcher:GetAllSearchItems()` — Returns table<HousingCatalogEntryID>
- `HousingCatalogEntryInfo.entryID` — Field on the info structure

### What returns decor source info?
**Nothing.** No API returns source/vendor information.

### What accepts recordID as input?
- `C_HousingCatalog.GetCatalogEntryInfoByRecordID(entryType, recordID, tryGetOwnedInfo)` — Tainted
- `C_HousingCatalog.GetCatalogEntryRefundTimeStampByRecordID(entryType, recordID)` — Tainted

### What connects catalog entries to merchant/vendor data?
**Nothing.** The Housing and Merchant APIs are completely separate.

## Recommended API Strategy for Homestead

### What Homestead should consider adopting

1. **New Events**: Register for these housing events:
   - `HOUSING_STORAGE_UPDATED` — Refresh ownership cache
   - `HOUSING_STORAGE_ENTRY_UPDATED` — Update specific entry
   - `HOUSING_LAYOUT_DECOR_PLACED` — Track when items are placed
   - `HOUSING_LAYOUT_DECOR_RETURNED_TO_STORAGE` — Track when items are returned

2. **Searcher Experimentation**: Test if addon code can:
   - Create a searcher and call `RunSearch()` with default settings
   - Read results after player interacts with Housing Catalog UI
   - Hook Blizzard's Housing Catalog frame to access their searcher

3. **Ownership Detection**: Use these untainted functions:
   - `C_HousingCatalog.GetDecorTotalOwnedCount()` — Already in use
   - `C_HousingCatalog.GetDecorMaxOwnedCount()` — Capacity checking

### What limitations exist

1. **Taint**: Most useful `GetCatalogEntryInfo*` functions are tainted
2. **No Source Data**: API provides NO vendor/source information
3. **Collection-Gating**: `entrySubtype = 1` indicates unowned, limited data available
4. **Category Info**: `GetCatalogCategoryInfo()` is tainted, can't get category names

### Whether vendor scanning can be supplemented or replaced

**Cannot be replaced.** The API does not provide:
- Which vendors sell which items
- Item prices at vendors
- Vendor locations
- Source information of any kind

**Vendor scanning remains essential.** The Housing API is designed for catalog 
browsing and placement, not acquisition tracking.

**Could be supplemented** by using `HOUSING_STORAGE_UPDATED` events to refresh 
the ownership cache more proactively, rather than relying solely on CatalogScanner.

### Any new features these APIs would enable

1. **Better Ownership Tracking**: `HOUSING_STORAGE_*` events provide real-time updates
2. **Placement Tracking**: Know when items are placed vs. in storage
3. **Category Filtering**: Could potentially filter owned items by category
4. **Dye Information**: `HousingDecorDyeSlot` structure provides dye slot data
5. **Preview Integration**: Events for preview list could enhance UI

**Bottom line**: The Housing API is useful for ownership and placement tracking, 
but provides zero information about where items come from. The static vendor 
database and in-game scanning remain the only way to build vendor-item mappings.
