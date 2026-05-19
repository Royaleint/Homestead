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

    core = read("Core/core.lua")
    map_provider = read("UI/MapPinProvider.lua")
    minimap_overlay = read("UI/HomesteadMinimapOverlay.lua")
    world_provider = read("UI/HomesteadWorldMapProvider.lua")
    waypoints = read("Utils/waypoints.lua")

    require(map_provider, "UI/MapPinProvider.lua", "GetManualGeographyAuditReport", failures)
    require(map_provider, "UI/MapPinProvider.lua", "AddManualGeographyAuditRow", failures)
    require(map_provider, "UI/MapPinProvider.lua", "native_ok", failures)
    require(map_provider, "UI/MapPinProvider.lua", "manual_required", failures)
    require(map_provider, "UI/MapPinProvider.lua", "manual_redundant_candidate", failures)
    require(core, "Core/core.lua", "debug geography", failures)
    require(core, "Core/core.lua", "PrintManualGeographyAuditReport", failures)

    require(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "GetHybridMinimapState", failures)
    require(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "C_Minimap.ShouldUseHybridMinimap", failures)
    require(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "hybridMinimap:IsShown()", failures)
    require(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "HybridMinimap active; Homestead minimap pins hidden", failures)
    require(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "return frameShown == true, reason, shouldUse == true, frameShown == true", failures)
    forbid(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "local active = shouldUse or frameShown", failures)
    forbid(minimap_overlay, "UI/HomesteadMinimapOverlay.lua", "return {", failures)

    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "watcherStats", failures)
    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "GetWatcherStats", failures)
    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "watcher_map_changed", failures)
    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "watcher_resize", failures)
    require(world_provider, "UI/HomesteadWorldMapProvider.lua", "watcher_zoom", failures)
    forbid(world_provider, "UI/HomesteadWorldMapProvider.lua", "hooksecurefunc(WorldMapFrame", failures)
    forbid(world_provider, "UI/HomesteadWorldMapProvider.lua", "WorldMapFrame:HookScript", failures)

    require(waypoints, "Utils/waypoints.lua", "UI_MAP_WAYPOINT_SUPER_TRACK_ON", failures)
    require(waypoints, "Utils/waypoints.lua", "UI_MAP_WAYPOINT_REMOVE", failures)
    require(waypoints, "Utils/waypoints.lua", "Waypoint set to", failures)
    forbid(waypoints, "Utils/waypoints.lua", "self:Clear(false)", failures)

    if failures:
        print("HS-088 final polish verification failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("HS-088 final polish verification passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
