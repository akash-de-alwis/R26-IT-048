def detect_major_intersections(steps):
    """
    Find intersections where 3+ roads meet (likely uncontrolled
    junctions in Sri Lankan context).
    """
    intersections = []
    for step in steps:
        ints = step.get('intersections', [])
        for inter in ints:
            bearings = inter.get('bearings', [])
            if len(bearings) >= 3:
                loc = inter.get('location', [])
                if not loc or len(loc) < 2:
                    continue
                roads_count = len(bearings)
                if roads_count >= 4:  severity = 'WARNING'
                else:                 severity = 'CAUTION'
                intersections.append({
                    'lat': loc[1], 'lng': loc[0],
                    'roads_meeting': roads_count,
                    'severity': severity,
                })
    return intersections
