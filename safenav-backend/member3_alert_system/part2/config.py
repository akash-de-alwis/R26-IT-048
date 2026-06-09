from dotenv import load_dotenv
import os
load_dotenv()

MAPBOX_ACCESS_TOKEN = os.getenv('MAPBOX_ACCESS_TOKEN')
OVERPASS_API_URLS = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
]
MAPBOX_TILEQUERY_URL = (
    'https://api.mapbox.com/v4/mapbox.mapbox-terrain-v2/tilequery')

OBSTACLE_DETECTION_RADIUS_M = 50
ALERT_DISTANCE_M = 200
MIN_TIME_BETWEEN_ALERTS_SEC = 8

if not MAPBOX_ACCESS_TOKEN:
    raise RuntimeError('MAPBOX_ACCESS_TOKEN missing in .env')
