from typing import List
from math import atan2, degrees, radians, sin, cos, asin, sqrt

def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000
    dLat = radians(lat2 - lat1)
    dLon = radians(lon2 - lon1)
    a = sin(dLat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon/2)**2
    return 2 * R * asin(sqrt(a))

def _bearing(lat1, lon1, lat2, lon2):
    dlon = radians(lon2 - lon1)
    lat1r, lat2r = radians(lat1), radians(lat2)
    x = sin(dlon) * cos(lat2r)
    y = cos(lat1r) * sin(lat2r) - sin(lat1r) * cos(lat2r) * cos(dlon)
    return (degrees(atan2(x, y)) + 360) % 360

def detect_bends(geometry: List[List[float]]):
    """
    Detect sharp bends in route geometry using sliding 3-point window.
    Window distance threshold tuned for Mapbox geometry density.
    """
    bends = []
    if len(geometry) < 5:
        return bends

    last_bend_at_index = -10

    for i in range(1, len(geometry) - 1):
        p_prev = geometry[i - 1]
        p_curr = geometry[i]
        p_next = geometry[i + 1]

        d1 = haversine_m(p_prev[1], p_prev[0], p_curr[1], p_curr[0])
        d2 = haversine_m(p_curr[1], p_curr[0], p_next[1], p_next[0])

        # Skip windows that are extremely short (noise) or
        # extremely long (sparse geometry, not a real bend)
        if d1 < 5 or d2 < 5:
            continue
        if d1 > 500 or d2 > 500:
            continue

        b1 = _bearing(p_prev[1], p_prev[0], p_curr[1], p_curr[0])
        b2 = _bearing(p_curr[1], p_curr[0], p_next[1], p_next[0])
        delta = abs(b2 - b1)
        if delta > 180:
            delta = 360 - delta

        # Lower threshold to catch more bends
        if delta < 35:
            continue

        # Avoid duplicate detections for the same bend
        if i - last_bend_at_index < 3:
            continue

        if delta >= 75:
            severity = 'CRITICAL'
        elif delta >= 55:
            severity = 'WARNING'
        else:
            severity = 'CAUTION'

        bends.append({
            'lat': p_curr[1], 'lng': p_curr[0],
            'angle': round(delta, 1),
            'severity': severity,
        })
        last_bend_at_index = i

    return bends
