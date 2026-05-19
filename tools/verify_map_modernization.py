from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def read(relpath):
    return (ROOT / relpath).read_text(encoding="utf-8", errors="replace")


def require(text, relpath, needle, failures):
    if needle not in text:
        failures.append(f"{relpath}: expected implementation missing: {needle}")


def forbid(text, relpath, needle, failures):
    if needle in text:
        failures.append(f"{relpath}: forbidden implementation remains: {needle}")


def main():
    failures = []

    waypoints = read("Utils/waypoints.lua")
    map_provider = read("UI/MapPinProvider.lua")
    world_provider = read("UI/HomesteadWorldMapProvider.lua")
    vendor_pins = read("UI/VendorMapPins.lua")
    side_panel = read("UI/MapSidePanel.lua")

    forbid(waypoints, "Utils/waypoints.lua", "ClearAllSuperTracked", failures)
    require(waypoints, "Utils/waypoints.lua", "SetSuperTrackedUserWaypoint(false)", failures)
    require(waypoints, "Utils/waypoints.lua", "MAP_PIN_INVALID_MAP", failures)
    require(waypoints, "Utils/waypoints.lua", "GetDisplayableMapForPlayer", failures)

    require(map_provider, "UI/MapPinProvider.lua", "projectionRectCache", failures)
    require(map_provider, "UI/MapPinProvider.lua", "GetDisplayableMapForPlayer", failures)
    require(map_provider, "UI/MapPinProvider.lua", "GetMoreSpecificChildMapIDs", failures)
    require(map_provider, "UI/MapPinProvider.lua", "C_Map.MapHasArt", failures)

    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "lastCanvasHeight", failures)
    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "canvasHeight", failures)

    require(vendor_pins, "UI/VendorMapPins.lua", "MPP:GetMoreSpecificChildMapIDs", failures)
    require(vendor_pins, "UI/VendorMapPins.lua", "EmitChildCityBadges", failures)
    require(map_provider, "UI/MapPinProvider.lua", "GetImmediateCitySummaryChildMapIDs", failures)
    require(map_provider, "UI/MapPinProvider.lua", "childCitySummaryMaps", failures)
    forbid(vendor_pins, "UI/VendorMapPins.lua", "MPP:GetImmediateChildMapIDs", failures)
    forbid(vendor_pins, "UI/VendorMapPins.lua", "C_Map.GetMapChildrenInfo", failures)
    require(side_panel, "UI/MapSidePanel.lua", "MPP:GetMoreSpecificChildMapIDs", failures)
    forbid(side_panel, "UI/MapSidePanel.lua", "C_Map.GetMapChildrenInfo", failures)

    if failures:
        print("Map modernization verification failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Map modernization verification passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
