from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    pin_factory = ROOT / "UI" / "PinFrameFactory.lua"
    text = pin_factory.read_text(encoding="utf-8", errors="replace")

    failures = []
    forbidden = [
        "-- Colored backplate behind icon (only for non-default)",
        "frame.backplate",
        "CreateCircularBackplate(frame, mmSize + 2)",
    ]
    for needle in forbidden:
        if needle in text:
            failures.append(f"UI/PinFrameFactory.lua: minimap color backplate remains: {needle}")

    required = [
        "frame.icon:SetAtlas(\"housing-decor-vendor_32\", false)",
        "frame.icon:SetDesaturated(true)",
        "frame.icon:SetVertexColor(br, bg, bb, PinFrameFactory.DESAT_ALPHA)",
    ]
    for needle in required:
        if needle not in text:
            failures.append(f"UI/PinFrameFactory.lua: expected icon tint path missing: {needle}")

    if failures:
        print("Minimap pin visual verification failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Minimap pin visual verification passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
