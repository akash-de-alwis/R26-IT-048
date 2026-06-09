from typing import List
from .bend_detector import haversine_m

def detect_slopes(elevation_samples):
    """
    samples: list of (index, lng, lat, elevation_m)
    A slope is detected when elevation change between consecutive
    samples gives a gradient > 5%.
    Returns list of {lat, lng, gradient_pct, severity, direction}.
    """
    slopes = []
    if len(elevation_samples) < 2:
        return slopes

    for i in range(len(elevation_samples) - 1):
        _, lng1, lat1, e1 = elevation_samples[i]
        _, lng2, lat2, e2 = elevation_samples[i + 1]
        dist = haversine_m(lat1, lng1, lat2, lng2)
        if dist < 30:
            continue
        rise = e2 - e1
        if abs(rise) < 1.5:
            continue
        gradient = abs(rise) / dist * 100
        if gradient < 5:
            continue

        if gradient >= 12:  severity = 'CRITICAL'
        elif gradient >= 8: severity = 'WARNING'
        else:               severity = 'CAUTION'

        slopes.append({
            'lat': (lat1 + lat2) / 2,
            'lng': (lng1 + lng2) / 2,
            'gradient_pct': round(gradient, 1),
            'severity': severity,
            'direction': 'uphill' if rise > 0 else 'downhill',
        })
    return slopes
