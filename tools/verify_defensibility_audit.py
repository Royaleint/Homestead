#!/usr/bin/env python3
"""Static verifier for the defensibility-audit fix pass.

This is intentionally narrow: it checks the exact invariants from the audit
without trying to lint or model the whole addon.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def require(path: str, needle: str, description: str) -> None:
    if needle not in read(path):
        fail(f"{path}: missing {description}")


def forbid(path: str, pattern: str, description: str) -> None:
    text = read(path)
    if re.search(pattern, text):
        fail(f"{path}: still contains {description}")


def main() -> int:
    instant_files = [
        "Core/core.lua",
        "Modules/DecorClassifier.lua",
        "Modules/VendorScanner.lua",
        "Overlay/overlay.lua",
        "Overlay/Merchant.lua",
        "Overlay/Baganator.lua",
        "Overlay/Containers.lua",
        "Overlay/BetterBags.lua",
    ]
    for path in instant_files:
        forbid(path, r"(?<![\w.])GetItemInfoInstant\s*\(", "bare GetItemInfoInstant call")
        require(path, "C_Item.GetItemInfoInstant", "C_Item.GetItemInfoInstant migration")

    for path in ["Modules/VendorTracer.lua", "UI/VendorMapPins.lua"]:
        forbid(path, r"(?<![\w.])GetItemInfo\s*\(", "bare GetItemInfo call")
        require(path, "C_Item.GetItemInfo", "C_Item.GetItemInfo migration")

    require("Data/VendorData.lua", "C_CurrencyInfo.GetCoinTextureString", "coin texture namespace migration")
    forbid("Data/VendorData.lua", r"(?<![\w.])GetCoinTextureString\s*\(", "bare GetCoinTextureString call")

    vendor_scanner = read("Modules/VendorScanner.lua")
    if "currencyCount" in vendor_scanner:
        fail("Modules/VendorScanner.lua: currencyCount dead-code variable remains")
    require(
        "Modules/VendorScanner.lua",
        "local totalCosts = _G.GetMerchantItemCostInfo(i) or 0",
        "identity-preserving merchant cost count simplification",
    )

    require("Modules/ScanPersistence.lua", "scanData.coords and scanData.coords.x", "coords nil guard")
    require("Data/EndeavorsData.lua", "nextMilestone.milestoneOrderIndex and", "milestone nil guard")
    require("UI/OutputWindow.lua", "fontHeight = fontHeight or 14", "font height fallback")
    require("UI/OptionsControls.lua", "newR = newR or previousR", "color picker red fallback")
    require("UI/OptionsControls.lua", "newG = newG or previousG", "color picker green fallback")
    require("UI/OptionsControls.lua", "newB = newB or previousB", "color picker blue fallback")

    require("Data/SourceManager.lua", "wasEarnedByMe is the 13th return value", "achievement unpack comment")

    calendar = read("Modules/CalendarDetector.lua")
    require("Modules/CalendarDetector.lua", "C_DateAndTime.GetCurrentCalendarTime", "canonical date API")
    require("Modules/CalendarDetector.lua", "CalendarDetector.enableSeasonalDetection = true", "enabled seasonal detection flag")
    if re.search(r"C_DateInfo\s+and\s+C_DateInfo\.GetCurrentCalendarTime", calendar):
        fail("Modules/CalendarDetector.lua: ungated C_DateInfo date lookup remains")

    require("Core/constants.lua", "WELCOME_SEEN_VERSION_MAX", "shared welcome version max")
    require("UI/WelcomeFrame.lua", "WELCOME_SEEN_VERSION_MAX", "WelcomeFrame shared welcome version max")
    require("UI/WhatsNewFrame.lua", "WELCOME_SEEN_VERSION_MAX", "WhatsNewFrame shared welcome version max")
    forbid("UI/WhatsNewFrame.lua", r"for i = 1,\s*10 do", "magic welcome version bound")

    require("Data/SourceManager.lua", "C_Reputation.GetFactionDataByIndex", "deferred reputation fallback left present")
    require("UI/MapSidePanel.lua", "UIDropDownMenuTemplate", "deferred UIDropDownMenu path left present")

    print("defensibility audit verifier passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
