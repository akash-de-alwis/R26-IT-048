import httpx
from datetime import datetime, timedelta
from .config import OPENWEATHER_API_KEY, OPENWEATHER_BASE_URL
from .schemas import WeatherSnapshot, WeatherCondition

_cache = {}
CACHE_TTL_SECONDS = 600  # 10 minutes


async def get_current_weather(lat: float, lon: float) -> WeatherSnapshot:
    """
    Fetch current weather from OpenWeatherMap with 10-minute caching
    to avoid hitting the free tier rate limit.

    Cache key is rounded to 0.01 degrees (~1km grid) to maximise hits.
    """
    cache_key = (round(lat, 2), round(lon, 2))

    if cache_key in _cache:
        cached_data, cached_time = _cache[cache_key]
        if datetime.now() - cached_time < timedelta(seconds=CACHE_TTL_SECONDS):
            return cached_data

    url = f"{OPENWEATHER_BASE_URL}/weather"
    params = {
        'lat': lat,
        'lon': lon,
        'appid': OPENWEATHER_API_KEY,
        'units': 'metric',
    }

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

        main = data['weather'][0]['main'].lower()
        description = data['weather'][0]['description']
        rain_amount = data.get('rain', {}).get('1h', 0)

        condition = _map_condition(main, rain_amount)

        snapshot = WeatherSnapshot(
            condition=condition,
            temperature_c=data['main']['temp'],
            humidity_pct=data['main']['humidity'],
            wind_speed_kmh=data['wind']['speed'] * 3.6,
            visibility_m=data.get('visibility', 10000),
            description=description,
        )

        _cache[cache_key] = (snapshot, datetime.now())
        return snapshot

    except Exception as e:
        print(f'[weather_service] Error: {e}')
        return WeatherSnapshot(
            condition=WeatherCondition.CLEAR,
            temperature_c=28.0,
            humidity_pct=70,
            wind_speed_kmh=10.0,
            visibility_m=10000,
            description='Weather unavailable',
        )


def _map_condition(main: str, rain_1h: float) -> WeatherCondition:
    if main == 'thunderstorm':
        return WeatherCondition.THUNDERSTORM
    if main in ('rain', 'drizzle'):
        if rain_1h >= 4.0:
            return WeatherCondition.HEAVY_RAIN
        return WeatherCondition.RAIN
    if main == 'fog':
        return WeatherCondition.FOG
    if main in ('mist', 'haze'):
        return WeatherCondition.MIST
    if main == 'clouds':
        return WeatherCondition.CLOUDS
    return WeatherCondition.CLEAR
