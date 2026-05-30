#!/usr/bin/env python3
"""
SafeNav codebase restructuring script.
Run from: e:\accident mobile app v3
"""
import os
import re
import shutil
from pathlib import Path

ROOT = Path(r"e:\accident mobile app v3")
BACKEND = ROOT / "safenav-backend"
LIB = ROOT / "safenav" / "lib"

# ═══════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════

def posix(p):
    return str(p).replace("\\", "/")

def mkfile(p: Path, content=""):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")

def read(p: Path):
    return p.read_text(encoding="utf-8")

def write(p: Path, content: str):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")

def rm_empty_dirs(base: Path):
    for d in sorted(base.rglob("*"), key=lambda x: len(str(x)), reverse=True):
        if d.is_dir():
            try:
                d.rmdir()
                print(f"  Removed empty dir: {posix(d.relative_to(base))}")
            except OSError:
                pass  # not empty

def rm_pycache(base: Path):
    for d in base.rglob("__pycache__"):
        shutil.rmtree(d)
        print(f"  Removed __pycache__: {posix(d.relative_to(base))}")

# ═══════════════════════════════════════════════════════════════════
# PART 1 — BACKEND
# ═══════════════════════════════════════════════════════════════════

def restructure_backend():
    print("\n" + "="*60)
    print("BACKEND RESTRUCTURING")
    print("="*60)

    # ── Create __init__.py files ────────────────────────────────────
    inits = [
        "shared/__init__.py",
        "shared/models/__init__.py",
        "shared/utils/__init__.py",
        "member1_risk_prediction/__init__.py",
        "member1_risk_prediction/part1/__init__.py",
        "member1_risk_prediction/part2/__init__.py",
        "member2_route_engine/__init__.py",
        "member2_route_engine/part1/__init__.py",
        "member2_route_engine/part2/__init__.py",
        "member3_alert_system/__init__.py",
        "member3_alert_system/part1/__init__.py",
        "member3_alert_system/part2/__init__.py",
        "member4_driver_scoring/__init__.py",
        "member4_driver_scoring/part1/__init__.py",
        "member4_driver_scoring/part2/__init__.py",
    ]
    for rel in inits:
        mkfile(BACKEND / rel)

    # ── shared/config.py (was config.py) ────────────────────────────
    src = read(BACKEND / "config.py")
    # Fix: parent/".env" -> parent.parent/".env" since config.py moves one level deeper
    src = src.replace(
        '_dotenv_path = Path(__file__).parent / ".env"',
        '_dotenv_path = Path(__file__).parent.parent / ".env"'
    )
    write(BACKEND / "shared/config.py", src)
    (BACKEND / "config.py").unlink()
    print("  Moved: config.py -> shared/config.py")

    # ── shared/models/schemas.py ────────────────────────────────────
    shutil.move(str(BACKEND / "models/schemas.py"), str(BACKEND / "shared/models/schemas.py"))
    print("  Moved: models/schemas.py -> shared/models/schemas.py")

    # ── shared/utils/geo_utils.py ───────────────────────────────────
    shutil.move(str(BACKEND / "utils/geo_utils.py"), str(BACKEND / "shared/utils/geo_utils.py"))
    print("  Moved: utils/geo_utils.py -> shared/utils/geo_utils.py")

    # ── member1 data files ──────────────────────────────────────────
    (BACKEND / "member1_risk_prediction/data").mkdir(parents=True, exist_ok=True)
    shutil.move(str(BACKEND / "hotspot_risk_scores.json"),
                str(BACKEND / "member1_risk_prediction/data/hotspot_risk_scores.json"))
    shutil.move(str(BACKEND / "risk_model.pkl"),
                str(BACKEND / "member1_risk_prediction/data/risk_model.pkl"))
    print("  Moved: hotspot_risk_scores.json -> member1_risk_prediction/data/")
    print("  Moved: risk_model.pkl -> member1_risk_prediction/data/")

    # ── member1 part1: hotspot_service.py ───────────────────────────
    src = read(BACKEND / "member1_risk/services/hotspot_service.py")
    src = src.replace(
        "from utils.geo_utils import",
        "from shared.utils.geo_utils import"
    )
    src = src.replace(
        'os.path.join(os.path.dirname(__file__), "..", "..", "hotspot_risk_scores.json")',
        'os.path.join(os.path.dirname(__file__), "..", "data", "hotspot_risk_scores.json")'
    )
    write(BACKEND / "member1_risk_prediction/part1/hotspot_service.py", src)
    (BACKEND / "member1_risk/services/hotspot_service.py").unlink()
    print("  Moved: member1_risk/services/hotspot_service.py -> member1_risk_prediction/part1/")

    # ── member1 part1: risk_service.py ──────────────────────────────
    src = read(BACKEND / "member1_risk/services/risk_service.py")
    src = src.replace(
        'os.path.join(os.path.dirname(__file__), "..", "..", "risk_model.pkl")',
        'os.path.join(os.path.dirname(__file__), "..", "data", "risk_model.pkl")'
    )
    write(BACKEND / "member1_risk_prediction/part1/risk_service.py", src)
    (BACKEND / "member1_risk/services/risk_service.py").unlink()
    print("  Moved: member1_risk/services/risk_service.py -> member1_risk_prediction/part1/")

    # ── member1 part2 files (all relative imports stay, fix file paths) ─
    part2_files = [
        "config.py",
        "schemas.py",
        "weather_service.py",
        "road_condition_service.py",
        "router.py",
    ]
    for fname in part2_files:
        src = read(BACKEND / "services/member1_part2" / fname)
        write(BACKEND / "member1_risk_prediction/part2" / fname, src)
        (BACKEND / "services/member1_part2" / fname).unlink()
        print(f"  Moved: services/member1_part2/{fname} -> member1_risk_prediction/part2/")

    # Fix file paths in realtime_risk_service.py
    rs_path = BACKEND / "member1_risk_prediction/part2/realtime_risk_service.py"
    src = read(rs_path)
    src = src.replace(
        "os.path.join(\n    os.path.dirname(__file__), '..', '..', 'risk_model.pkl')",
        "os.path.join(\n    os.path.dirname(__file__), '..', 'data', 'risk_model.pkl')"
    )
    src = src.replace(
        "os.path.join(os.path.dirname(__file__), '..', '..', 'risk_model.pkl')",
        "os.path.join(os.path.dirname(__file__), '..', 'data', 'risk_model.pkl')"
    )
    src = src.replace(
        "os.path.join(\n    os.path.dirname(__file__), '..', '..', 'hotspot_risk_scores.json')",
        "os.path.join(\n    os.path.dirname(__file__), '..', 'data', 'hotspot_risk_scores.json')"
    )
    src = src.replace(
        "os.path.join(os.path.dirname(__file__), '..', '..', 'hotspot_risk_scores.json')",
        "os.path.join(os.path.dirname(__file__), '..', 'data', 'hotspot_risk_scores.json')"
    )
    write(rs_path, src)

    # ── member2 part1 ────────────────────────────────────────────────
    src = read(BACKEND / "member2_routing/services/astar_service.py")
    src = src.replace(
        "from utils.geo_utils import",
        "from shared.utils.geo_utils import"
    )
    src = src.replace(
        "from member1_risk.services.hotspot_service import",
        "from member1_risk_prediction.part1.hotspot_service import"
    )
    write(BACKEND / "member2_route_engine/part1/astar_service.py", src)
    (BACKEND / "member2_routing/services/astar_service.py").unlink()
    print("  Moved: member2_routing/services/astar_service.py -> member2_route_engine/part1/")

    shutil.move(str(BACKEND / "member2_routing/services/route_service.py"),
                str(BACKEND / "member2_route_engine/part1/route_service.py"))
    print("  Moved: member2_routing/services/route_service.py -> member2_route_engine/part1/")

    # ── member3 part1 ────────────────────────────────────────────────
    shutil.move(str(BACKEND / "member3_alerts/services/nlp_alert_service.py"),
                str(BACKEND / "member3_alert_system/part1/nlp_alert_service.py"))
    print("  Moved: member3_alerts/services/nlp_alert_service.py -> member3_alert_system/part1/")

    # ── Update main.py ───────────────────────────────────────────────
    src = read(BACKEND / "main.py")
    src = src.replace(
        "from config import OPENWEATHER_API_KEY",
        "from shared.config import OPENWEATHER_API_KEY"
    )
    src = src.replace(
        "from models.schemas import (",
        "from shared.models.schemas import ("
    )
    src = src.replace(
        "from member1_risk.services import hotspot_service, risk_service",
        "from member1_risk_prediction.part1 import hotspot_service, risk_service"
    )
    src = src.replace(
        "from member2_routing.services import route_service",
        "from member2_route_engine.part1 import route_service"
    )
    src = src.replace(
        "from member3_alerts.services import nlp_alert_service",
        "from member3_alert_system.part1 import nlp_alert_service"
    )
    src = src.replace(
        "from services.member1_part2.router import router as m1p2_router",
        "from member1_risk_prediction.part2.router import router as m1p2_router"
    )
    write(BACKEND / "main.py", src)
    print("  Updated: main.py imports")

    # ── Clean up old empty dirs ──────────────────────────────────────
    rm_pycache(BACKEND)
    old_dirs = [
        BACKEND / "models",
        BACKEND / "utils",
        BACKEND / "member1_risk",
        BACKEND / "member2_routing",
        BACKEND / "member3_alerts",
        BACKEND / "services",
    ]
    for d in old_dirs:
        if d.exists():
            try:
                shutil.rmtree(d)
                print(f"  Removed old dir: {d.name}/")
            except Exception as e:
                print(f"  WARNING: Could not remove {d}: {e}")

    print("\nBackend restructuring complete.")


# ═══════════════════════════════════════════════════════════════════
# PART 2 — FRONTEND
# ═══════════════════════════════════════════════════════════════════

# Map: lib-relative old path -> lib-relative new path
DART_MOVES = {
    "core/constants/app_constants.dart":        "shared/constants/app_constants.dart",
    "core/theme/app_colors.dart":               "shared/theme/app_colors.dart",
    "core/theme/app_theme.dart":                "shared/theme/app_theme.dart",
    "core/services/api_service.dart":           "shared/services/api_service.dart",
    "core/services/auth_service.dart":          "shared/services/auth_service.dart",
    "core/services/geocoding_service.dart":     "shared/services/geocoding_service.dart",
    "core/services/offline_map_service.dart":   "shared/services/offline_map_service.dart",
    "core/providers/app_provider.dart":         "shared/providers/app_provider.dart",
    "core/models/hotspot_model.dart":           "member1_risk_prediction/part1/models/hotspot_model.dart",

    "features/auth/screens/login_screen.dart":              "screens/auth/login_screen.dart",
    "features/billing/screens/billing_screen.dart":         "screens/billing/billing_screen.dart",
    "features/dashboard/screens/dashboard_screen.dart":     "screens/dashboard/dashboard_screen.dart",
    "features/map/screens/map_screen.dart":                 "screens/map/map_screen.dart",
    "features/onboarding/screens/onboarding_screen.dart":   "screens/onboarding/onboarding_screen.dart",
    "features/onboarding/screens/splash_screen.dart":       "screens/onboarding/splash_screen.dart",
    "features/profile/widgets/stat_card_widget.dart":       "screens/profile/stat_card_widget.dart",
    "features/home/widgets/hotspot_marker_painter.dart":    "member1_risk_prediction/part1/widgets/hotspot_marker_painter.dart",
    "features/home/widgets/offline_map_sheet.dart":         "shared/widgets/offline_map_sheet.dart",
    "features/home/widgets/place_search_sheet.dart":        "shared/widgets/place_search_sheet.dart",
    "features/home/widgets/search_bar_widget.dart":         "shared/widgets/search_bar_widget.dart",
    "features/home/screens/dashboard_screen.dart":          "screens/dashboard/home_dashboard_screen.dart",
    "features/driver_score/widgets/segmented_gauge.dart":   "member4_driver_scoring/part1/widgets/segmented_gauge.dart",
    "features/member1_part2/models/realtime_risk_model.dart":     "member1_risk_prediction/part2/models/realtime_risk_model.dart",
    "features/member1_part2/models/risk_factor_model.dart":       "member1_risk_prediction/part2/models/risk_factor_model.dart",
    "features/member1_part2/models/weather_snapshot_model.dart":  "member1_risk_prediction/part2/models/weather_snapshot_model.dart",
    "features/member1_part2/services/realtime_risk_service.dart": "member1_risk_prediction/part2/services/realtime_risk_service.dart",
    "features/member1_part2/widgets/realtime_risk_hud.dart":      "member1_risk_prediction/part2/widgets/realtime_risk_hud.dart",
    "features/member1_part2/widgets/risk_detail_sheet.dart":      "member1_risk_prediction/part2/widgets/risk_detail_sheet.dart",
    "features/member1_part2/widgets/risk_factor_chip.dart":       "member1_risk_prediction/part2/widgets/risk_factor_chip.dart",

    "member1_risk/services/hotspot_api_service.dart":    "member1_risk_prediction/part1/services/hotspot_api_service.dart",
    "member1_risk/widgets/hotspot_legend_widget.dart":   "member1_risk_prediction/part1/widgets/hotspot_legend_widget.dart",
    "member1_risk/widgets/hotspot_marker_layer.dart":    "member1_risk_prediction/part1/widgets/hotspot_marker_layer.dart",

    "member2_routing/models/route_model.dart":           "member2_route_engine/part1/models/route_model.dart",
    "member2_routing/services/route_api_service.dart":   "member2_route_engine/part1/services/route_api_service.dart",
    "member2_routing/widgets/route_layer_widget.dart":   "member2_route_engine/part1/widgets/route_layer_widget.dart",
    "member2_routing/widgets/route_options_sheet.dart":  "member2_route_engine/part1/widgets/route_options_sheet.dart",

    "member3_alerts/models/alert_model.dart":            "member3_alert_system/part1/models/alert_model.dart",
    "member3_alerts/services/alert_service.dart":        "member3_alert_system/part1/services/alert_service.dart",
    "member3_alerts/services/notification_service.dart": "member3_alert_system/part1/services/notification_service.dart",
    "member3_alerts/widgets/alert_settings_widget.dart": "member3_alert_system/part1/widgets/alert_settings_widget.dart",
    "member3_alerts/widgets/safety_alert_card.dart":     "member3_alert_system/part1/widgets/safety_alert_card.dart",

    "member4_scoring/models/driving_event.dart":          "member4_driver_scoring/part1/models/driving_event.dart",
    "member4_scoring/models/trip_session.dart":           "member4_driver_scoring/part1/models/trip_session.dart",
    "member4_scoring/services/sensor_service.dart":       "member4_driver_scoring/part1/services/sensor_service.dart",
    "member4_scoring/widgets/score_gauge_widget.dart":    "member4_driver_scoring/part1/widgets/score_gauge_widget.dart",
    "member4_scoring/widgets/trip_event_card.dart":       "member4_driver_scoring/part1/widgets/trip_event_card.dart",
    "member4_scoring/widgets/live_score_banner.dart":     "member4_driver_scoring/part1/widgets/live_score_banner.dart",
    "member4_scoring/widgets/behavior_alerts_widget.dart": "member4_driver_scoring/part1/widgets/behavior_alerts_widget.dart",

    "shared/screens/driver_score_screen.dart":   "member4_driver_scoring/part1/screens/driver_score_screen.dart",
    "shared/screens/trip_summary_screen.dart":   "member4_driver_scoring/part1/screens/trip_summary_screen.dart",
    "shared/screens/profile_screen.dart":        "screens/profile/profile_screen.dart",
    "shared/screens/home_screen.dart":           "screens/map/home_screen.dart",
}


def resolve_import(from_lib_rel: str, imp: str) -> str:
    """Resolve a relative import path to a lib-relative absolute path."""
    from_dir = str(Path(from_lib_rel).parent).replace("\\", "/")
    if from_dir == ".":
        # file is directly in lib/
        combined = imp
    else:
        combined = from_dir + "/" + imp

    # Normalize path components
    parts = combined.split("/")
    normalized = []
    for part in parts:
        if part == "..":
            if normalized:
                normalized.pop()
        elif part not in (".", ""):
            normalized.append(part)
    return "/".join(normalized)


def new_relative_import(new_file_lib_rel: str, target_lib_rel: str) -> str:
    """Compute the new relative import string from a file to a target (both lib-relative)."""
    from_dir = posix(Path(new_file_lib_rel).parent)
    # Use os.path.relpath
    rel = os.path.relpath(target_lib_rel, from_dir).replace("\\", "/")
    if not rel.startswith("."):
        rel = "./" + rel
    return rel


def update_dart_imports(old_lib_rel: str, new_lib_rel: str, content: str) -> str:
    """Rewrite all relative imports in a Dart file."""
    def replace_one(m):
        imp = m.group(1)
        if imp.startswith("package:") or imp.startswith("dart:"):
            return m.group(0)
        # Resolve old relative import to lib-absolute
        target_old = resolve_import(old_lib_rel, imp)
        # Look up where that target moved to
        target_new = DART_MOVES.get(target_old, target_old)
        # Compute new relative path from the file's new location
        new_imp = new_relative_import(new_lib_rel, target_new)
        return f"import '{new_imp}';"

    return re.sub(r"import '([^']+)';", replace_one, content)


def restructure_frontend():
    print("\n" + "="*60)
    print("FRONTEND RESTRUCTURING")
    print("="*60)

    # Collect all .dart files BEFORE moving anything
    dart_files = list(LIB.rglob("*.dart"))

    for f in dart_files:
        lib_rel = posix(f.relative_to(LIB))
        new_lib_rel = DART_MOVES.get(lib_rel, lib_rel)

        content = read(f)
        new_content = update_dart_imports(lib_rel, new_lib_rel, content)

        new_path = LIB / new_lib_rel
        new_path.parent.mkdir(parents=True, exist_ok=True)
        write(new_path, new_content)

        if lib_rel != new_lib_rel:
            # Only remove old file if we wrote to a different location
            f.unlink()
            print(f"  Moved: {lib_rel}")
            print(f"      -> {new_lib_rel}")
        else:
            print(f"  Updated: {lib_rel}")

    # Remove old (now empty) directories
    print("\n  Cleaning up empty directories...")
    old_dirs = [
        LIB / "core",
        LIB / "features",
        LIB / "member1_risk",
        LIB / "member2_routing",
        LIB / "member3_alerts",
        LIB / "member4_scoring",
    ]
    for d in old_dirs:
        if d.exists():
            # Remove any remaining files first (shouldn't be any)
            remaining = list(d.rglob("*.dart"))
            if remaining:
                print(f"  WARNING: {d.name}/ still has files: {[posix(r.relative_to(LIB)) for r in remaining]}")
            else:
                shutil.rmtree(d)
                print(f"  Removed old dir: {d.name}/")

    # Also remove shared/screens/ (now empty)
    shared_screens = LIB / "shared" / "screens"
    if shared_screens.exists():
        remaining = list(shared_screens.rglob("*.dart"))
        if not remaining:
            shutil.rmtree(shared_screens)
            print("  Removed old dir: shared/screens/")
        else:
            print(f"  WARNING: shared/screens/ still has: {remaining}")

    print("\nFrontend restructuring complete.")


# ═══════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    restructure_backend()
    restructure_frontend()
    print("\n" + "="*60)
    print("ALL DONE. Run flutter analyze next.")
    print("="*60)
