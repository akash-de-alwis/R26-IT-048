from .schemas import WeatherSnapshot, WeatherCondition, RoadCondition


def infer_road_condition(weather: WeatherSnapshot) -> RoadCondition:
    """
    Infer road surface condition from current weather.
    Heuristic approach since direct road sensors are unavailable.
    """
    if weather.condition in (WeatherCondition.FOG, WeatherCondition.MIST):
        return RoadCondition.POOR_VISIBILITY
    if weather.condition in (WeatherCondition.HEAVY_RAIN,
                              WeatherCondition.THUNDERSTORM):
        return RoadCondition.SLIPPERY
    if weather.condition == WeatherCondition.RAIN:
        return RoadCondition.WET
    if weather.visibility_m < 2000:
        return RoadCondition.POOR_VISIBILITY
    return RoadCondition.DRY
