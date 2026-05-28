import os
from pathlib import Path

from dotenv import load_dotenv

_dotenv_path = Path(__file__).parent.parent / ".env"
if _dotenv_path.exists():
    load_dotenv(_dotenv_path)

OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
