# Homestead Code Audit Report
Generated: 2026-02-05
Addon Version: @project-version@
Interface Version: 120000
Auditor: OpenAI Codex

## 1. File Inventory
| # | File | Load Order | Purpose | Modified? |
|---|------|------------|---------|-----------|
| 1 | `embeds.xml` | 1 | Library loader | No |
| 2 | `Libs/WagoAnalytics/Shim.lua` | 2 | Optional analytics shim | No |
| 3 | `Locale/enUS.lua` | 3 | Localization | No |
| 4 | `Core/constants.lua` | 4 | Constants, defaults, icons | Yes |
| 5 | `Core/core.lua` | 5 | AceAddon lifecycle, slash commands | Yes |
| 6 | `Core/events.lua` | 6 | Inter-module event/throttle system | No |
| 7 | `Core/cache.lua` | 7 | Cache tiers | No |
| 8 | `Data/DecorData.lua` | 8 | Decor data model | No |
| 9 | `Data/VendorDatabase.lua` | 9 | Static vendor DB + indexes | No |
| 10 | `Data/VendorData.lua` | 10 | Unified vendor access | No |
| 11 | `Data/AchievementDecor.lua` | 11 | Legacy achievement sources | No |
| 12 | `Data/QuestSources.lua` | 12 | Quest sources | No |
| 13 | `Data/AchievementSources.lua` | 13 | Achievement sources | No |
| 14 | `Data/ProfessionSources.lua` | 14 | Profession sources | No |
| 15 | `Data/DropSources.lua` | 15 | Drop sources | No |
| 16 | `Data/SourceManager.lua` | 16 | Unified source lookup | No |
| 17 | `Utils/waypoints.lua` | 17 | Waypoint utility | No |
| 18 | `Modules/DecorTracker.lua` | 18 | Ownership detection | No |
| 19 | `Modules/CatalogScanner.lua` | 19 | Ownership cache scanning | No |
| 20 | `Modules/VendorTracer.lua` | 20 | Vendor navigation | No |
| 21 | `Modules/VendorScanner.lua` | 21 | Vendor scanning | No |
| 22 | `Modules/ExportImport.lua` | 22 | Export/import | Yes |
| 23 | `Modules/Validation.lua` | 23 | Data validation | No |
| 24 | `Overlay/overlay.lua` | 24 | Overlay framework | No |
| 25 | `Overlay/Containers.lua` | 25 | Bag/bank overlays | Yes |
| 26 | `Overlay/Merchant.lua` | 26 | Merchant overlays | Yes |
| 27 | `Overlay/Tooltips.lua` | 27 | Tooltip enhancements | Yes |
| 28 | `UI/WelcomeFrame.lua` | 28 | Onboarding | No |
| 29 | `UI/MainFrame.lua` | 29 | Main UI window | No |
| 30 | `UI/OutputWindow.lua` | 30 | Output popup | No |
| 31 | `UI/VendorMapPins.lua` | 31 | Map/minimap pins | No |
| 32 | `UI/Options.lua` | 32 | AceConfig options | No |

## 2. Namespace Pattern
- Root namespace: `HA` from `local addonName, HA = ...`
- Framework: Ace3 (`AceAddon`, `AceDB`, `AceEvent`, `AceConsole`, `AceConfig`)
- Intentional globals: only the allowlisted symbols below.

## 3. Global Namespace Findings
| # | Symbol | File:Line | Pattern | Severity | Status |
|---|--------|-----------|---------|----------|--------|
| 1 | `Homestead` | `Core/core.lua:22` | _G_write | MEDIUM | Allowed |
| 2 | `HomesteadMainFrame` | `UI/MainFrame.lua:31` | intentional | ACCEPTABLE | Allowed |
| 3 | `HomesteadWelcomeFrame` | `UI/WelcomeFrame.lua:102` | intentional | ACCEPTABLE | Allowed |
| 4 | `HomesteadOutputWindow` | `UI/OutputWindow.lua:26` | intentional | ACCEPTABLE | Allowed |
| 5 | `HomesteadExportFrame` | `Modules/ExportImport.lua:49` | intentional | ACCEPTABLE | Allowed |
| 6 | `HomesteadExportDialog` | `Modules/ExportImport.lua:159` | intentional | ACCEPTABLE | Allowed |
| 7 | `StaticPopupDialogs["HOMESTEAD_CLEAR_CACHE"]` | `UI/MainFrame.lua:637` | intentional | ACCEPTABLE | Allowed |

Before/After summary:
| Metric | Before | After |
|--------|--------|-------|
| Total addon globals | 10 | 7 |
| HIGH severity | 1 | 0 |
| MEDIUM severity | 2 | 1 |
| LOW severity | 3 | 0 |
| ACCEPTABLE | 4 | 6 |

## 4. Global Allowlist
| Symbol | File | Justification |
|--------|------|---------------|
| `Homestead` | `Core/core.lua` | Intentional addon interop table |
| `HomesteadMainFrame` | `UI/MainFrame.lua` | Required for UISpecialFrames (Escape-to-close) |
| `HomesteadWelcomeFrame` | `UI/WelcomeFrame.lua` | Required for UISpecialFrames (Escape-to-close) |
| `HomesteadOutputWindow` | `UI/OutputWindow.lua` | Required for UISpecialFrames (Escape-to-close) |
| `HomesteadExportFrame` | `Modules/ExportImport.lua` | Required for UISpecialFrames (Escape-to-close) |
| `HomesteadExportDialog` | `Modules/ExportImport.lua` | Required for UISpecialFrames (Escape-to-close) |
| `StaticPopupDialogs["HOMESTEAD_CLEAR_CACHE"]` | `UI/MainFrame.lua` | Required for Blizzard StaticPopupDialogs system |

## 5. Deprecated / Risky API Findings
| # | API | File:Line | Category | Replacement | Confidence | Status |
|---|-----|-----------|----------|-------------|------------|--------|
| 1 | `GetContainerItemLink` | `Overlay/Containers.lua:117` | Deprecated | `C_Container.GetContainerItemLink` | High | Fixed |
| 2 | `GameTooltip:HookScript("OnTooltipSetItem")` fallback | `Overlay/Tooltips.lua:~550` | Legacy | `TooltipDataProcessor` primary path | High | Removed |

Before/After summary:
| Metric | Before | After |
|--------|--------|-------|
| Deprecated API calls flagged | 2 | 0 |

## 6. Changes Made
| File | Line | What Changed | Before | After |
|------|------|--------------|--------|-------|
| `Core/constants.lua` | ~282 | Removed duplicate `_G` write | `_G[addonName] = HA` | Removed |
| `Core/core.lua` | ~20–22 | Added intent comment for global | none | comment above `_G.Homestead` |
| `Core/core.lua` | ~897 | Remove global frame name | `CreateFrame(..., "HomesteadCopyFrame", ...)` | `CreateFrame(..., nil, ...)` |
| `Overlay/Merchant.lua` | 117 | Make helper local | `function UpdateAllMerchantOverlays()` | `local function UpdateAllMerchantOverlays()` |
| `Modules/ExportImport.lua` | 49 | Restore `HomesteadExportFrame` global | `CreateFrame(..., nil, ...)` | `CreateFrame(..., "HomesteadExportFrame", ...)` |
| `Modules/ExportImport.lua` | ~55 | Restore escape close | (none) | `tinsert(UISpecialFrames, "HomesteadExportFrame")` |
| `Modules/ExportImport.lua` | 159 | Restore `HomesteadExportDialog` global | `CreateFrame(..., nil, ...)` | `CreateFrame(..., "HomesteadExportDialog", ...)` |
| `Modules/ExportImport.lua` | ~163 | Restore escape close | (none) | `tinsert(UISpecialFrames, "HomesteadExportDialog")` |
| `Overlay/Containers.lua` | 117 | Update container API | `GetContainerItemLink` | `C_Container.GetContainerItemLink` |
| `Overlay/Tooltips.lua` | ~540–565 | Remove legacy tooltip fallback | `GameTooltip:HookScript(...)` | Removed |

## 7. Remaining Issues
None — all findings resolved.

## 8. Compliance Statement
Yes — the addon complies with: “Addons must not heavily pollute the global namespace or use deprecated functions.”

## 9. Notes for Claude
- `_G.Homestead` retained as intentional interop/debug global with explicit comment.
- `C_HousingCatalog` calls are **not** deprecated; taint sensitivity is handled with nil checks.
- Files modified: `Core/constants.lua`, `Core/core.lua`, `Overlay/Merchant.lua`, `Modules/ExportImport.lua`, `Overlay/Containers.lua`, `Overlay/Tooltips.lua`.
- Known limitations: regex-based global scans cannot fully interpret Lua scope; manual verification was applied to ensure only allowlisted globals remain.
