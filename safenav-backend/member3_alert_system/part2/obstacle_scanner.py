"""Main orchestrator — combines all detectors into one scan."""
import uuid
from datetime import datetime
from typing import List
from collections import defaultdict
from .schemas import (
    Obstacle, ObstacleType, ObstacleSeverity,
    ObstacleScanRequest, ObstacleScanResponse)
from .bend_detector import detect_bends, haversine_m
from .slope_detector import detect_slopes
from .narrow_road_detector import detect_narrow_road_segments
from .intersection_detector import detect_major_intersections
from .mapbox_elevation_service import get_elevations_for_route
from .overpass_service import fetch_obstacles_in_bbox, get_bbox_from_route
from .nlp_alert_service import build_alert_text
from .report_service import reports_on_route

OBSTACLE_ICONS = {
    ObstacleType.SHARP_BEND:   "turn_sharp_right",
    ObstacleType.STEEP_SLOPE:  "trending_up",
    ObstacleType.NARROW_ROAD:  "compress",
    ObstacleType.INTERSECTION: "share",
    ObstacleType.SPEED_BUMP:   "horizontal_rule",
    ObstacleType.BARRIER:      "block",
    ObstacleType.CROSSING:     "directions_walk",
    ObstacleType.USER_REPORTED:"flag",
}

SEVERITY_COLORS = {
    ObstacleSeverity.CRITICAL: "#FF3B5C",
    ObstacleSeverity.WARNING:  "#FF8C42",
    ObstacleSeverity.CAUTION:  "#FFB300",
}

OBSTACLE_DESCRIPTIONS = {
    ObstacleType.SHARP_BEND:    ("Sharp bend in road",     "මාර්ගයේ තියුණු වංගුවක්"),
    ObstacleType.STEEP_SLOPE:   ("Steep gradient",         "තද බෑවුම"),
    ObstacleType.NARROW_ROAD:   ("Narrow road segment",    "පටු මාර්ග කොටස"),
    ObstacleType.INTERSECTION:  ("Major intersection",     "ප්‍රධාන හන්දිය"),
    ObstacleType.SPEED_BUMP:    ("Speed bump or hump",     "වේග බාධකය"),
    ObstacleType.BARRIER:       ("Physical barrier",       "භෞතික බාධකය"),
    ObstacleType.CROSSING:      ("Pedestrian crossing",    "පදික මාරුව"),
    ObstacleType.USER_REPORTED: ("User reported hazard",   "පරිශීලක වාර්තා කළ අවදානම"),
}

def _build_obstacle(
    obs_type: ObstacleType, severity_str: str,
    lat: float, lng: float,
    metric_value=None, metric_unit=None,
    distance_from_route_m: float = 0,
) -> Obstacle:
    severity = ObstacleSeverity(severity_str) if isinstance(severity_str, str) else severity_str
    desc_en, desc_si = OBSTACLE_DESCRIPTIONS[obs_type]

    return Obstacle(
        id=str(uuid.uuid4())[:12],
        obstacle_type=obs_type,
        severity=severity,
        latitude=lat, longitude=lng,
        distance_from_route_m=round(distance_from_route_m, 1),
        icon_name=OBSTACLE_ICONS[obs_type],
        color=SEVERITY_COLORS[severity],
        metric_value=metric_value,
        metric_unit=metric_unit,
        description_en=desc_en,
        description_si=desc_si,
        alert=build_alert_text(obs_type, severity, metric_value, metric_unit))

def _classify_osm_element(elem) -> tuple:
    """
    Classify an OSM node OR way into our obstacle taxonomy.
    Returns (ObstacleType, severity) or (None, None) if not relevant.
    """
    tags = elem.get('tags', {}) or {}

    # Speed bumps and traffic calming devices
    if tags.get('traffic_calming'):
        tc = tags.get('traffic_calming', '').lower()
        if tc in ['bump', 'hump', 'table']:
            return (ObstacleType.SPEED_BUMP, 'WARNING')
        return (ObstacleType.SPEED_BUMP, 'CAUTION')

    # Physical barriers
    barrier = tags.get('barrier', '').lower()
    if barrier:
        if barrier in ['gate', 'lift_gate', 'swing_gate', 'block']:
            return (ObstacleType.BARRIER, 'WARNING')
        if barrier in ['bollard', 'cycle_barrier', 'chain']:
            return (ObstacleType.BARRIER, 'CAUTION')
        return (ObstacleType.BARRIER, 'CAUTION')

    # Pedestrian crossings (usually nodes on highways)
    if tags.get('highway') == 'crossing':
        crossing_type = tags.get('crossing', '').lower()
        if crossing_type in ['zebra', 'marked', 'traffic_signals']:
            return (ObstacleType.CROSSING, 'WARNING')
        return (ObstacleType.CROSSING, 'CAUTION')

    # Pedestrian-only streets/zones (these are usually ways)
    if tags.get('highway') == 'pedestrian':
        return (ObstacleType.CROSSING, 'WARNING')

    # No-access zones
    if tags.get('access') == 'no':
        return (ObstacleType.BARRIER, 'WARNING')

    return (None, None)

def _is_near_route(geometry, lat, lng, threshold_m=50):
    sample_step = max(1, len(geometry) // 60)
    for i in range(0, len(geometry), sample_step):
        rlng, rlat = geometry[i][0], geometry[i][1]
        if haversine_m(lat, lng, rlat, rlng) <= threshold_m:
            return True
    return False

def _distance_to_route(geometry, lat, lng):
    min_d = float('inf')
    sample_step = max(1, len(geometry) // 80)
    for i in range(0, len(geometry), sample_step):
        rlng, rlat = geometry[i][0], geometry[i][1]
        d = haversine_m(lat, lng, rlat, rlng)
        if d < min_d: min_d = d
    return min_d

async def scan_route_for_obstacles(
    req: ObstacleScanRequest, steps: List = None,
) -> ObstacleScanResponse:
    geometry = req.route_geometry
    obstacles: List[Obstacle] = []

    # 1) BENDS
    for b in detect_bends(geometry):
        obstacles.append(_build_obstacle(
            ObstacleType.SHARP_BEND, b['severity'],
            b['lat'], b['lng'],
            metric_value=b['angle'], metric_unit='degrees'))
    print(f"[scanner] Bends detected: {len(obstacles)}")

    # 2) SLOPES
    try:
        samples = await get_elevations_for_route(geometry, sample_step=10)
        for s in detect_slopes(samples):
            obstacles.append(_build_obstacle(
                ObstacleType.STEEP_SLOPE, s['severity'],
                s['lat'], s['lng'],
                metric_value=s['gradient_pct'], metric_unit='percent'))
    except Exception as e:
        print(f"[scanner] elevation failed: {e}")
    print(f"[scanner] Total after slopes: {len(obstacles)}")

    # 3) NARROW ROADS (only if steps provided)
    if steps:
        for n in detect_narrow_road_segments(steps):
            obstacles.append(_build_obstacle(
                ObstacleType.NARROW_ROAD, n['severity'],
                n['lat'], n['lng']))

    # 4) INTERSECTIONS (only if steps provided)
    if steps:
        for inter in detect_major_intersections(steps):
            if _is_near_route(geometry, inter['lat'], inter['lng'], 30):
                obstacles.append(_build_obstacle(
                    ObstacleType.INTERSECTION, inter['severity'],
                    inter['lat'], inter['lng']))

    # 5-7) OSM OBSTACLES
    bbox = get_bbox_from_route(geometry, pad=0.003)
    osm_nodes = await fetch_obstacles_in_bbox(*bbox)
    print(f"[scanner] OSM elements returned: {len(osm_nodes)}")

    # Build a node lookup so ways can resolve their member nodes
    node_lookup = {}
    for elem in osm_nodes:
        if elem.get('type') == 'node':
            nid = elem.get('id')
            if nid is not None:
                node_lookup[nid] = (elem.get('lat'), elem.get('lon'))

    for elem in osm_nodes:
        elem_type = elem.get('type')
        lat = None
        lng = None

        if elem_type == 'node':
            lat = elem.get('lat')
            lng = elem.get('lon')
        elif elem_type == 'way':
            # Get the way's middle node coordinate
            node_ids = elem.get('nodes', [])
            if not node_ids:
                continue
            mid_id = node_ids[len(node_ids) // 2]
            if mid_id in node_lookup:
                lat, lng = node_lookup[mid_id]

        if lat is None or lng is None:
            continue

        obs_type, severity = _classify_osm_element(elem)
        if not obs_type:
            continue
        if not _is_near_route(geometry, lat, lng, 40):
            continue
        d = _distance_to_route(geometry, lat, lng)
        obstacles.append(_build_obstacle(
            obs_type, severity, lat, lng,
            distance_from_route_m=d))
    print(f"[scanner] Total before dedup: {len(obstacles)}")

    # 8) USER REPORTS
    for r in reports_on_route(geometry, threshold_m=80):
        obstacles.append(_build_obstacle(
            ObstacleType.USER_REPORTED, r.severity.value,
            r.latitude, r.longitude))

    # Dedup close-by obstacles of same type (within 25m)
    deduped = []
    for o in obstacles:
        is_dup = False
        for d in deduped:
            if (d.obstacle_type == o.obstacle_type and
                haversine_m(d.latitude, d.longitude,
                            o.latitude, o.longitude) < 25):
                is_dup = True
                break
        if not is_dup:
            deduped.append(o)
    print(f"[scanner] Final obstacle count: {len(deduped)}")

    counts_by_type = defaultdict(int)
    counts_by_sev = defaultdict(int)
    for o in deduped:
        counts_by_type[o.obstacle_type.value] += 1
        counts_by_sev[o.severity.value] += 1

    return ObstacleScanResponse(
        obstacles=deduped,
        total_count=len(deduped),
        counts_by_type=dict(counts_by_type),
        counts_by_severity=dict(counts_by_sev),
        scan_timestamp=datetime.now().isoformat())
