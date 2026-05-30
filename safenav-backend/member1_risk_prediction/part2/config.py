from dotenv import load_dotenv
import os

load_dotenv()

OPENWEATHER_API_KEY = os.getenv('OPENWEATHER_API_KEY')
OPENWEATHER_BASE_URL = os.getenv(
    'OPENWEATHER_BASE_URL',
    'https://api.openweathermap.org/data/2.5'
)

if not OPENWEATHER_API_KEY:
    raise RuntimeError(
        'OPENWEATHER_API_KEY missing. Add it to .env file.')
