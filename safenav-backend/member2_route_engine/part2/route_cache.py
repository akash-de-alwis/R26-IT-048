import time
from typing import Optional, Any

# In-process route cache with stale-if-error fallback.
_CACHE: dict = {}
FRESH_SECONDS = 300          # serve instantly for 5 min
STALE_SECONDS = 6 * 3600     # usable as fallback for 6 hours
MAX_ENTRIES = 200


def make_key(o_lat, o_lng, d_lat, d_lng, vehicle="car"):
    r = lambda v: round(float(v), 3)     # ~100 m grid
    return f"{r(o_lat)},{r(o_lng)}|{r(d_lat)},{r(d_lng)}|{vehicle}"


def get_fresh(key) -> Optional[Any]:
    e = _CACHE.get(key)
    if e and time.time() - e["t"] < FRESH_SECONDS:
        return e["v"]
    return None


def get_stale(key) -> Optional[Any]:
    e = _CACHE.get(key)
    if e and time.time() - e["t"] < STALE_SECONDS:
        return e["v"]
    return None


def put(key, value):
    if key not in _CACHE and len(_CACHE) >= MAX_ENTRIES:
        oldest = min(_CACHE, key=lambda k: _CACHE[k]["t"])
        _CACHE.pop(oldest, None)
    _CACHE[key] = {"t": time.time(), "v": value}
