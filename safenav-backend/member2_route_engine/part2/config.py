from dotenv import load_dotenv
import os

load_dotenv()

MAPBOX_ACCESS_TOKEN = os.getenv('MAPBOX_ACCESS_TOKEN')
MAPBOX_DIRECTIONS_BASE = 'https://api.mapbox.com/directions/v5/mapbox'

if not MAPBOX_ACCESS_TOKEN:
    raise RuntimeError('MAPBOX_ACCESS_TOKEN missing in .env file')
