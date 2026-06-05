NARROW_CLASSES = {'residential', 'service', 'unclassified'}

def detect_narrow_road_segments(steps):
    """
    Look at Mapbox step data. Mark stretches > 200m on narrow
    road classes as narrow-road obstacles.
    """
    narrows = []
    accumulated_distance = 0
    segment_start = None

    for step in steps:
        intersections = step.get('intersections', [])
        if not intersections:
            continue
        classes = intersections[0].get('classes', []) or []
        road_class = (classes[0] if classes else 'unclassified').replace('_link', '')
        step_dist = step.get('distance', 0)
        step_geom = step.get('geometry', {}).get('coordinates', [])
        if not step_geom:
            continue

        if road_class in NARROW_CLASSES:
            if segment_start is None:
                segment_start = step_geom[0]
            accumulated_distance += step_dist
        else:
            if segment_start and accumulated_distance > 200:
                mid_idx = len(step_geom) // 2
                narrows.append({
                    'lat': step_geom[mid_idx][1],
                    'lng': step_geom[mid_idx][0],
                    'distance_m': round(accumulated_distance),
                    'severity': 'CAUTION',
                    'road_class': road_class,
                })
            segment_start = None
            accumulated_distance = 0

    return narrows
