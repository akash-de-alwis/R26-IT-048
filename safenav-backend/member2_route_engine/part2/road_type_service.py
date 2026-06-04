from typing import List, Dict
from collections import defaultdict
from .schemas import RoadClass, RoadTypeBreakdown

# Research-backed per-km risk weights by road class
ROAD_CLASS_RISK_MULTIPLIERS = {
    RoadClass.MOTORWAY:     0.85,
    RoadClass.TRUNK:        0.95,
    RoadClass.PRIMARY:      1.00,
    RoadClass.SECONDARY:    1.10,
    RoadClass.TERTIARY:     1.20,
    RoadClass.RESIDENTIAL:  1.35,
    RoadClass.SERVICE:      1.40,
    RoadClass.UNCLASSIFIED: 1.15,
}

ROAD_CLASS_LABELS = {
    RoadClass.MOTORWAY:     "Highway",
    RoadClass.TRUNK:        "Trunk Road",
    RoadClass.PRIMARY:      "Main Road",
    RoadClass.SECONDARY:    "Secondary Road",
    RoadClass.TERTIARY:     "Local Arterial",
    RoadClass.RESIDENTIAL:  "Residential",
    RoadClass.SERVICE:      "Service Road",
    RoadClass.UNCLASSIFIED: "Unclassified",
}


def parse_road_class(class_str: str) -> RoadClass:
    if not class_str:
        return RoadClass.UNCLASSIFIED
    # Mapbox returns motorway_link, primary_link etc. — strip suffix
    base = class_str.replace('_link', '')
    try:
        return RoadClass(base.lower())
    except ValueError:
        return RoadClass.UNCLASSIFIED


def extract_road_types(route: dict) -> List[RoadTypeBreakdown]:
    """
    Mapbox returns road class info inside step.intersections.
    Aggregates distance per road class across all steps.
    """
    distance_by_class: Dict[RoadClass, float] = defaultdict(float)

    steps = route['legs'][0].get('steps', [])

    for step in steps:
        step_distance = step.get('distance', 0)
        intersections = step.get('intersections', [])

        if intersections:
            classes = intersections[0].get('classes', [])
            if classes:
                road_class = parse_road_class(classes[0])
            else:
                road_class = _guess_class_from_name(
                    step.get('name', ''), step.get('ref', ''))
        else:
            road_class = RoadClass.UNCLASSIFIED

        distance_by_class[road_class] += step_distance

    total_distance = sum(distance_by_class.values()) or 1

    breakdown = [
        RoadTypeBreakdown(
            road_class=road_class,
            distance_m=round(dist, 1),
            pct_of_route=round((dist / total_distance) * 100, 1),
            risk_multiplier=ROAD_CLASS_RISK_MULTIPLIERS[road_class])
        for road_class, dist in distance_by_class.items()
    ]

    breakdown.sort(key=lambda b: b.distance_m, reverse=True)
    return breakdown


def _guess_class_from_name(name: str, ref: str) -> RoadClass:
    """Heuristic fallback when Mapbox doesn't provide intersection classes."""
    if not name and not ref:
        return RoadClass.UNCLASSIFIED
    ref_lower = (ref or '').lower()
    name_lower = (name or '').lower()

    if 'e0' in ref_lower or 'expressway' in name_lower:
        return RoadClass.MOTORWAY
    if 'a' in ref_lower[:2] or 'galle road' in name_lower or 'highway' in name_lower:
        return RoadClass.PRIMARY
    if 'b' in ref_lower[:2]:
        return RoadClass.SECONDARY
    if 'road' in name_lower or 'mawatha' in name_lower:
        return RoadClass.TERTIARY
    if 'lane' in name_lower or 'street' in name_lower:
        return RoadClass.RESIDENTIAL
    return RoadClass.UNCLASSIFIED


def avg_road_type_risk(breakdown: List[RoadTypeBreakdown]) -> float:
    """Distance-weighted average road-class risk for the entire route."""
    if not breakdown:
        return 1.0
    total = sum(b.distance_m for b in breakdown) or 1
    weighted = sum(b.risk_multiplier * b.distance_m for b in breakdown)
    return weighted / total


def primary_class(breakdown: List[RoadTypeBreakdown]) -> RoadClass:
    if not breakdown:
        return RoadClass.UNCLASSIFIED
    return breakdown[0].road_class
