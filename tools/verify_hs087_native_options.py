from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

CHECKS = [
    ("UI/Options.lua", ["AceConfig", "AceConfigDialog", "AceConfigRegistry", "AceGUI"]),
    ("Core/core.lua", ["AceConfigDialog"]),
    ("Homestead.toc", ["UI\\PinColorPreviewWidget.lua"]),
    ("embeds.xml", ["AceGUI-3.0", "AceConfig-3.0"]),
    (".pkgmeta", ["Libs/AceGUI-3.0", "Libs/AceConfig-3.0"]),
]

REQUIRED = {
    "Homestead.toc": [
        "UI/OptionsModel.lua",
        "UI/OptionsControls.lua",
        "UI/OptionsFrame.lua",
        "UI/Options.lua",
    ],
    "UI/OptionsFrame.lua": [
        "local NAV_SELECTED_COLOR",
        "ApplyNavButtonState",
        "button.selectedTexture",
        "GetSectionHeaderRow",
        "GetSectionDescriptionRow",
        "GetHeaderDescriptionRow",
        "HOMESTEAD_PORTRAIT_TEXTURE",
        'CreateFrame("Frame", "HomesteadOptionsFrame", UIParent, "PortraitFrameTemplate")',
        'ownerFrame:SetFrameStrata("HIGH")',
        "ownerFrame:SetToplevel(true)",
        "frame:Raise()",
        'CreateFrame("Frame", nil, content, "InsetFrameTemplate")',
        "ownerFrame.navInset",
        "ownerFrame.contentInset",
    ],
    "UI/OptionsControls.lua": [
        "CreateHeaderSeparator",
        "CreateSliderTrackBackground",
        "GameFontHighlightLarge",
        "separator:SetColorTexture",
        "trackBackground:SetColorTexture",
        "CONTROL_RIGHT_PADDING",
        'dropdown:SetPoint("RIGHT"',
    ],
    "UI/OptionsModel.lua": [
        "desc_options_general",
        "desc_options_overlays",
        "desc_options_tooltips",
        "desc_options_world_map",
        "desc_options_minimap",
        "desc_options_endeavors",
        "desc_options_export",
        "desc_vendor_visibility_section",
        "desc_pin_appearance_section",
        "desc_overlay_inventory_section",
        "desc_overlay_merchant_section",
        "desc_overlay_catalog_section",
        "desc_tooltip_map_pins_section",
        "desc_minimap_waypoints_section",
    ],
}

DELETED = [
    "UI/PinColorPreviewWidget.lua",
]

FORBIDDEN_SNIPPETS = {
    "UI/OptionsFrame.lua": [
        'CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")',
        "house-drawing-stone-bg",
        "backgroundShade",
        "navBackground",
        'CreateFrame("Frame", "HomesteadOptionsFrame", UIParent, "DefaultPanelTemplate")',
        "SetPropagateKeyboardInput",
        "FULLSCREEN_DIALOG",
        "EnableKeyboard",
        "OnKeyDown",
    ],
}

def read(relpath):
    path = ROOT / relpath
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8", errors="replace")

def normalize_paths(text):
    return text.replace("\\", "/")

def main():
    failures = []
    for relpath, forbidden in CHECKS:
        text = read(relpath)
        if text is None:
            failures.append(f"{relpath}: expected file missing")
            continue
        if relpath == "Homestead.toc":
            text = normalize_paths(text)
            forbidden = [normalize_paths(needle) for needle in forbidden]
        for needle in forbidden:
            if needle in text:
                failures.append(f"{relpath}: forbidden reference remains: {needle}")
    for relpath, required in REQUIRED.items():
        text = read(relpath)
        if text is None:
            failures.append(f"{relpath}: expected file missing")
            continue
        if relpath == "Homestead.toc":
            text = normalize_paths(text)
        for needle in required:
            if needle not in text:
                failures.append(f"{relpath}: required entry missing: {needle}")
    for relpath, forbidden in FORBIDDEN_SNIPPETS.items():
        text = read(relpath)
        if text is None:
            failures.append(f"{relpath}: expected file missing")
            continue
        for needle in forbidden:
            if needle in text:
                failures.append(f"{relpath}: forbidden implementation remains: {needle}")
    for relpath in DELETED:
        if (ROOT / relpath).exists():
            failures.append(f"{relpath}: file should be removed")

    if failures:
        print("HS-087 native options verification failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("HS-087 native options verification passed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
