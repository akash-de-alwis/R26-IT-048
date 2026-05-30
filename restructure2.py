#!/usr/bin/env python3
"""Continue backend + full frontend restructuring."""
import os, re, shutil
from pathlib import Path

ROOT = Path(r"e:\accident mobile app v3")
BACKEND = ROOT / "safenav-backend"
LIB = ROOT / "safenav" / "lib"

def posix(p): return str(p).replace("\\", "/")
def mkfile(p, content=""): Path(p).parent.mkdir(parents=True, exist_ok=True); Path(p).write_text(content, encoding="utf-8")
def read(p): return Path(p).read_text(encoding="utf-8")
def write(p, content): Path(p).parent.mkdir(parents=True, exist_ok=True); Path(p).write_text(content, encoding="utf-8")
def mv(src, dst):
    src, dst = Path(src), Path(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dst))

print("="*60)
print("BACKEND (remaining steps)")
print("="*60)

# shared/models/schemas.py
if (BACKEND/"models/schemas.py").exists():
    mv(BACKEND/"models/schemas.py", BACKEND/"shared/models/schemas.py")
    print("  Moved: models/schemas.py -> shared/models/schemas.py")

# shared/utils/geo_utils.py
if (BACKEND/"utils/geo_utils.py").exists():
    mv(BACKEND/"utils/geo_utils.py", BACKEND/"shared/utils/geo_utils.py")
    print("  Moved: utils/geo_utils.py -> shared/utils/geo_utils.py")

# data files
(BACKEND/"member1_risk_prediction/data").mkdir(parents=True, exist_ok=True)
if (BACKEND/"hotspot_risk_scores.json").exists():
    mv(BACKEND/"hotspot_risk_scores.json", BACKEND/"member1_risk_prediction/data/hotspot_risk_scores.json")
    print("  Moved: hotspot_risk_scores.json -> member1_risk_prediction/data/")
if (BACKEND/"risk_model.pkl").exists():
    mv(BACKEND/"risk_model.pkl", BACKEND/"member1_risk_prediction/data/risk_model.pkl")
    print("  Moved: risk_model.pkl -> member1_risk_prediction/data/")

# member1 part1: hotspot_service.py
if (BACKEND/"member1_risk/services/hotspot_service.py").exists():
    src = read(BACKEND/"member1_risk/services/hotspot_service.py")
    src = src.replace("from utils.geo_utils import", "from shared.utils.geo_utils import")
    src = src.replace(
        'os.path.join(os.path.dirname(__file__), "..", "..", "hotspot_risk_scores.json")',
        'os.path.join(os.path.dirname(__file__), "..", "data", "hotspot_risk_scores.json")'
    )
    write(BACKEND/"member1_risk_prediction/part1/hotspot_service.py", src)
    (BACKEND/"member1_risk/services/hotspot_service.py").unlink()
    print("  Moved: member1_risk/services/hotspot_service.py -> member1_risk_prediction/part1/")

# member1 part1: risk_service.py
if (BACKEND/"member1_risk/services/risk_service.py").exists():
    src = read(BACKEND/"member1_risk/services/risk_service.py")
    src = src.replace(
        'os.path.join(os.path.dirname(__file__), "..", "..", "risk_model.pkl")',
        'os.path.join(os.path.dirname(__file__), "..", "data", "risk_model.pkl")'
    )
    write(BACKEND/"member1_risk_prediction/part1/risk_service.py", src)
    (BACKEND/"member1_risk/services/risk_service.py").unlink()
    print("  Moved: member1_risk/services/risk_service.py -> member1_risk_prediction/part1/")

# member1 part2
for fname in ["config.py","schemas.py","weather_service.py","road_condition_service.py","router.py"]:
    src_f = BACKEND/"services/member1_part2"/fname
    if src_f.exists():
        mv(src_f, BACKEND/"member1_risk_prediction/part2"/fname)
        print(f"  Moved: services/member1_part2/{fname} -> member1_risk_prediction/part2/")

# fix file paths in realtime_risk_service.py
rs = BACKEND/"member1_risk_prediction/part2/realtime_risk_service.py"
if rs.exists():
    src = read(rs)
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
    write(rs, src)
    print("  Fixed file paths in realtime_risk_service.py")

# member2 part1
if (BACKEND/"member2_routing/services/astar_service.py").exists():
    src = read(BACKEND/"member2_routing/services/astar_service.py")
    src = src.replace("from utils.geo_utils import", "from shared.utils.geo_utils import")
    src = src.replace("from member1_risk.services.hotspot_service import",
                      "from member1_risk_prediction.part1.hotspot_service import")
    write(BACKEND/"member2_route_engine/part1/astar_service.py", src)
    (BACKEND/"member2_routing/services/astar_service.py").unlink()
    print("  Moved: member2_routing/services/astar_service.py -> member2_route_engine/part1/")

if (BACKEND/"member2_routing/services/route_service.py").exists():
    mv(BACKEND/"member2_routing/services/route_service.py",
       BACKEND/"member2_route_engine/part1/route_service.py")
    print("  Moved: route_service.py -> member2_route_engine/part1/")

# member3 part1
if (BACKEND/"member3_alerts/services/nlp_alert_service.py").exists():
    mv(BACKEND/"member3_alerts/services/nlp_alert_service.py",
       BACKEND/"member3_alert_system/part1/nlp_alert_service.py")
    print("  Moved: nlp_alert_service.py -> member3_alert_system/part1/")

# update main.py
src = read(BACKEND/"main.py")
src = src.replace("from config import OPENWEATHER_API_KEY", "from shared.config import OPENWEATHER_API_KEY")
src = src.replace("from models.schemas import (", "from shared.models.schemas import (")
src = src.replace("from member1_risk.services import hotspot_service, risk_service",
                  "from member1_risk_prediction.part1 import hotspot_service, risk_service")
src = src.replace("from member2_routing.services import route_service",
                  "from member2_route_engine.part1 import route_service")
src = src.replace("from member3_alerts.services import nlp_alert_service",
                  "from member3_alert_system.part1 import nlp_alert_service")
src = src.replace("from services.member1_part2.router import router as m1p2_router",
                  "from member1_risk_prediction.part2.router import router as m1p2_router")
write(BACKEND/"main.py", src)
print("  Updated: main.py")

# clean up old dirs
for d in ["models","utils","member1_risk","member2_routing","member3_alerts","services"]:
    p = BACKEND/d
    if p.exists():
        # remove all __init__.py inside (they'll be empty)
        for f in p.rglob("__init__.py"):
            f.unlink()
        try:
            shutil.rmtree(p)
            print(f"  Removed old dir: {d}/")
        except Exception as e:
            print(f"  WARNING removing {d}/: {e}")

# remove pycache
for d in list(BACKEND.rglob("__pycache__")):
    shutil.rmtree(d)

print("\nBackend done.")

# ═══════════════════════════════════════════════════════════════════
# FRONTEND
# ═══════════════════════════════════════════════════════════════════

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

    "features/auth/screens/login_screen.dart":            "screens/auth/login_screen.dart",
    "features/billing/screens/billing_screen.dart":       "screens/billing/billing_screen.dart",
    "features/dashboard/screens/dashboard_screen.dart":   "screens/dashboard/dashboard_screen.dart",
    "features/map/screens/map_screen.dart":               "screens/map/map_screen.dart",
    "features/onboarding/screens/onboarding_screen.dart": "screens/onboarding/onboarding_screen.dart",
    "features/onboarding/screens/splash_screen.dart":     "screens/onboarding/splash_screen.dart",
    "features/profile/widgets/stat_card_widget.dart":     "screens/profile/stat_card_widget.dart",
    "features/home/widgets/hotspot_marker_painter.dart":  "member1_risk_prediction/part1/widgets/hotspot_marker_painter.dart",
    "features/home/widgets/offline_map_sheet.dart":       "shared/widgets/offline_map_sheet.dart",
    "features/home/widgets/place_search_sheet.dart":      "shared/widgets/place_search_sheet.dart",
    "features/home/widgets/search_bar_widget.dart":       "shared/widgets/search_bar_widget.dart",
    "features/home/screens/dashboard_screen.dart":        "screens/dashboard/home_dashboard_screen.dart",
    "features/driver_score/widgets/segmented_gauge.dart": "member4_driver_scoring/part1/widgets/segmented_gauge.dart",
    "features/member1_part2/models/realtime_risk_model.dart":     "member1_risk_prediction/part2/models/realtime_risk_model.dart",
    "features/member1_part2/models/risk_factor_model.dart":       "member1_risk_prediction/part2/models/risk_factor_model.dart",
    "features/member1_part2/models/weather_snapshot_model.dart":  "member1_risk_prediction/part2/models/weather_snapshot_model.dart",
    "features/member1_part2/services/realtime_risk_service.dart": "member1_risk_prediction/part2/services/realtime_risk_service.dart",
    "features/member1_part2/widgets/realtime_risk_hud.dart":      "member1_risk_prediction/part2/widgets/realtime_risk_hud.dart",
    "features/member1_part2/widgets/risk_detail_sheet.dart":      "member1_risk_prediction/part2/widgets/risk_detail_sheet.dart",
    "features/member1_part2/widgets/risk_factor_chip.dart":       "member1_risk_prediction/part2/widgets/risk_factor_chip.dart",

    "member1_risk/services/hotspot_api_service.dart":   "member1_risk_prediction/part1/services/hotspot_api_service.dart",
    "member1_risk/widgets/hotspot_legend_widget.dart":  "member1_risk_prediction/part1/widgets/hotspot_legend_widget.dart",
    "member1_risk/widgets/hotspot_marker_layer.dart":   "member1_risk_prediction/part1/widgets/hotspot_marker_layer.dart",

    "member2_routing/models/route_model.dart":          "member2_route_engine/part1/models/route_model.dart",
    "member2_routing/services/route_api_service.dart":  "member2_route_engine/part1/services/route_api_service.dart",
    "member2_routing/widgets/route_layer_widget.dart":  "member2_route_engine/part1/widgets/route_layer_widget.dart",
    "member2_routing/widgets/route_options_sheet.dart": "member2_route_engine/part1/widgets/route_options_sheet.dart",

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
    "member4_scoring/widgets/behavior_alerts_widget.dart":"member4_driver_scoring/part1/widgets/behavior_alerts_widget.dart",

    "shared/screens/driver_score_screen.dart": "member4_driver_scoring/part1/screens/driver_score_screen.dart",
    "shared/screens/trip_summary_screen.dart": "member4_driver_scoring/part1/screens/trip_summary_screen.dart",
    "shared/screens/profile_screen.dart":      "screens/profile/profile_screen.dart",
    "shared/screens/home_screen.dart":         "screens/map/home_screen.dart",
}

def resolve_import(from_lib_rel, imp):
    from_dir = posix(Path(from_lib_rel).parent)
    if from_dir == ".":
        combined = imp
    else:
        combined = from_dir + "/" + imp
    parts = combined.split("/")
    norm = []
    for part in parts:
        if part == "..":
            if norm: norm.pop()
        elif part not in (".", ""):
            norm.append(part)
    return "/".join(norm)

def new_rel_import(new_file_lib_rel, target_lib_rel):
    from_dir = posix(Path(new_file_lib_rel).parent)
    if from_dir == ".":
        from_dir = "."
    rel = os.path.relpath(target_lib_rel, from_dir).replace("\\", "/")
    if not rel.startswith("."):
        rel = "./" + rel
    return rel

def update_dart_imports(old_lib_rel, new_lib_rel, content):
    def replace_one(m):
        imp = m.group(1)
        if imp.startswith("package:") or imp.startswith("dart:"):
            return m.group(0)
        target_old = resolve_import(old_lib_rel, imp)
        target_new = DART_MOVES.get(target_old, target_old)
        new_imp = new_rel_import(new_lib_rel, target_new)
        return f"import '{new_imp}';"
    return re.sub(r"import '([^']+)';", replace_one, content)

print("\n" + "="*60)
print("FRONTEND RESTRUCTURING")
print("="*60)

dart_files = list(LIB.rglob("*.dart"))
print(f"  Processing {len(dart_files)} Dart files...")

for f in dart_files:
    lib_rel = posix(f.relative_to(LIB))
    new_lib_rel = DART_MOVES.get(lib_rel, lib_rel)
    content = read(f)
    new_content = update_dart_imports(lib_rel, new_lib_rel, content)
    new_path = LIB / new_lib_rel
    new_path.parent.mkdir(parents=True, exist_ok=True)
    write(new_path, new_content)
    if lib_rel != new_lib_rel:
        f.unlink()
        print(f"  Moved: {lib_rel}")
        print(f"      -> {new_lib_rel}")
    else:
        print(f"  Updated: {lib_rel}")

# Remove old empty dirs
print("\n  Cleaning old directories...")
old_dirs = ["core", "features", "member1_risk", "member2_routing",
            "member3_alerts", "member4_scoring"]
for dname in old_dirs:
    d = LIB / dname
    if d.exists():
        remaining = list(d.rglob("*.dart"))
        if remaining:
            print(f"  WARNING: {dname}/ still has {len(remaining)} dart file(s)")
            for r in remaining:
                print(f"    {posix(r.relative_to(LIB))}")
        else:
            shutil.rmtree(d)
            print(f"  Removed: {dname}/")

shared_screens = LIB / "shared" / "screens"
if shared_screens.exists():
    remaining = list(shared_screens.rglob("*.dart"))
    if not remaining:
        shutil.rmtree(shared_screens)
        print("  Removed: shared/screens/")
    else:
        print(f"  WARNING: shared/screens/ still has files: {remaining}")

print("\nFrontend done.")
print("\n" + "="*60)
print("ALL DONE — run flutter analyze next.")
print("="*60)
