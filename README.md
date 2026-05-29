# SafeNav - Accident Risk Navigation App

A mobile application that helps drivers navigate safely by detecting accident hotspots, providing risk-aware routing, monitoring driver behavior, and delivering real-time safety alerts. Developed for the Panadura, Sri Lanka road network.

---

## Features

### Accident Hotspot Visualization
- Map overlay of accident-prone locations with color-coded risk levels
- Nearby hotspot detection within a configurable radius (300–500 m)
- Real-time risk scoring based on location, time of day, weather context, and vehicle type

### Real-Time Risk HUD
- Continuous risk assessment overlay powered by live weather (OpenWeatherMap) and inferred road conditions
- ML model combines base accident probability with speed, weather, and road surface factors
- In-app HUD and detail sheet surfacing risk level, contributing factors, and contextual advice

### Safe Route Planning
- A\*-algorithm-based route safety ranking with three modes: **Safest**, **Balanced**, **Fastest**
- Integration with Mapbox Directions API for real road geometry
- Side-by-side route comparison showing safety scores for each alternative
- Offline map support for low-connectivity environments

### Real-Time Safety Alerts
- Proximity-triggered alerts every 5 seconds while driving
- NLP-generated contextual warnings in **English and Sinhala**
- Text-to-speech voice announcements for hands-free awareness
- Alert prioritization based on driver behavior and environmental context
- Local push notifications for out-of-app alerting
- Tap any alert card to open a full detail sheet (renders above the navigation bar via root navigator)

### Driver Safety Scoring
- Live safety score (0–100) using onboard accelerometer and gyroscope
- Detects harsh braking (−8 pts), harsh acceleration (−5 pts), sharp turns (−4 pts), and overspeeding >70 km/h (−6 pts)
- Smooth driving earns +2 pts per interval
- Trip session tracking with full event history and score gauge visualization

### Authentication & Onboarding
- Firebase Authentication with Google Sign-In
- Onboarding flow and splash screen for first-time users
- Profile screen with trip statistics

---

## Tech Stack

### Mobile App (Flutter)
| Package | Purpose |
|---|---|
| `mapbox_maps_flutter ^2.4.0` | Interactive map rendering |
| `geolocator ^12.0.0` | GPS location tracking |
| `sensors_plus ^6.0.0` | Accelerometer & gyroscope |
| `flutter_tts ^4.0.2` | Text-to-speech alerts |
| `flutter_local_notifications ^18.0.0` | Push notifications |
| `provider ^6.1.2` | State management |
| `go_router ^14.0.0` | Tab-based navigation |
| `http ^1.2.2` | REST API client |
| `firebase_core ^3.3.0` | Firebase SDK |
| `firebase_auth ^5.1.3` | Firebase Authentication |
| `google_sign_in ^6.2.1` | Google Sign-In |
| `shared_preferences ^2.3.2` | Local key-value storage |
| `google_fonts ^6.2.1` | Custom typography |
| `flutter_dotenv ^5.1.0` | Environment variable management |
| `permission_handler ^11.3.1` | Runtime permissions |

### Backend (Python / FastAPI)
| Package | Purpose |
|---|---|
| `fastapi 0.111.0` | REST API framework |
| `uvicorn 0.29.0` | ASGI server |
| `scikit-learn 1.4.2` | ML risk prediction model |
| `pandas / numpy` | Data processing |
| `pydantic 2.7.1` | Request/response validation |
| `python-dotenv` | Environment variable loading |

---

## Architecture

```
accident mobile app v3/
├── safenav/                              # Flutter mobile application
│   └── lib/
│       ├── main.dart                     # Entry point, permissions, Mapbox init
│       ├── app.dart                      # Router & bottom navigation shell
│       ├── screens/
│       │   ├── auth/                     # Login screen (Firebase / Google)
│       │   ├── onboarding/               # Splash & onboarding screens
│       │   ├── dashboard/                # Home dashboard screens
│       │   ├── map/                      # Main map & home screens
│       │   ├── profile/                  # User profile & stats
│       │   └── billing/                  # Billing screen
│       ├── shared/
│       │   ├── constants/                # App-wide constants
│       │   ├── providers/                # AppProvider (ChangeNotifier)
│       │   ├── services/                 # API, auth, geocoding, offline map
│       │   ├── theme/                    # Colors & theme configuration
│       │   └── widgets/                  # Shared UI components
│       ├── member1_risk_prediction/
│       │   ├── part1/                    # Hotspot map UI & risk overlay
│       │   └── part2/                    # Real-time risk HUD & detail sheet
│       ├── member2_route_engine/
│       │   └── part1/                    # Route planning & comparison screens
│       ├── member3_alert_system/
│       │   └── part1/                    # Alert display, TTS & notifications
│       └── member4_driver_scoring/
│           └── part1/                    # Score gauge, trip events & sensor service
│
└── safenav-backend/                      # Python FastAPI backend
    ├── main.py                           # All API route definitions
    ├── shared/
    │   ├── config.py                     # Environment config (OpenWeather key)
    │   ├── models/schemas.py             # Pydantic schemas
    │   └── utils/geo_utils.py            # Haversine & geo helpers
    ├── member1_risk_prediction/
    │   ├── part1/                        # Hotspot service & ML risk inference
    │   └── part2/                        # Weather-aware real-time risk service
    ├── member2_route_engine/
    │   └── part1/                        # A* route safety ranking service
    ├── member3_alert_system/
    │   └── part1/                        # NLP alert generation service
    ├── member4_driver_scoring/           # (reserved for future backend scoring)
    ├── risk_model.pkl                    # Pre-trained scikit-learn model
    └── hotspot_risk_scores.json          # Precomputed hotspot dataset
```

**State management:** Provider (ChangeNotifier pattern)  
**Navigation:** Go Router with indexed shell route for tab persistence

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Server health check |
| `GET` | `/hotspots` | All accident hotspots (optional `?risk_level=` filter) |
| `GET` | `/hotspots/near?lat=&lng=&radius_m=300` | Hotspots within radius |
| `GET` | `/hotspots/{id}` | Single hotspot details |
| `POST` | `/route/safety` | Rank route alternatives by safety score |
| `POST` | `/predict/realtime` | ML risk prediction with NLP alert generation |
| `POST` | `/alerts/nearby` | Prioritized NLP-generated alerts for nearby hotspots |
| `POST` | `/v2/risk/realtime` | Enhanced risk prediction with live weather & road conditions |
| `GET` | `/v2/risk/health` | Health check for real-time risk module |

The backend runs on `http://localhost:8000` (Android emulator: `http://10.0.2.2:8000`).  
Interactive API docs available at `http://localhost:8000/docs`.

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.x
- Python 3.10+
- A [Mapbox](https://www.mapbox.com/) account and public access token
- A [Firebase](https://firebase.google.com/) project with Authentication enabled (Google Sign-In)
- An [OpenWeatherMap](https://openweathermap.org/) API key (for real-time risk HUD)
- Android Studio / Xcode for device emulation

### Backend Setup

1. Create a `.env` file in `safenav-backend/`:
   ```env
   OPENWEATHER_API_KEY=your_key_here
   ```
2. Install dependencies and start the server:
   ```bash
   cd safenav-backend
   pip install -r requirements.txt
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

### Mobile App Setup

1. Place your Firebase `google-services.json` (Android) in `safenav/android/app/`.
2. Create a `.env` file in `safenav/` with your Mapbox token:
   ```env
   MAPBOX_ACCESS_TOKEN=your_token_here
   ```
3. Install dependencies:
   ```bash
   cd safenav
   flutter pub get
   ```
4. Run on a connected device or emulator:
   ```bash
   flutter run
   ```

> **Note:** Location and sensor permissions are requested at runtime. For accurate alert testing on an emulator, set the GPS coordinates to Sri Lanka (e.g., 6.713265, 79.906280). Ensure the backend is reachable from your device/emulator before launching.

---

## ML Model

The risk prediction model (`risk_model.pkl`) is a scikit-learn classifier trained on historical accident data for the Panadura region. It takes the following features as input:

- Geographic coordinates (latitude, longitude)
- Temporal features: hour, day of week, month, is_night, is_weekend
- Vehicle type (motorcycle, car, bus, etc.)

The `/v2/risk/realtime` endpoint extends this model with live weather data (precipitation, visibility, wind) and inferred road conditions (wet/dry surface, road type) for higher-fidelity predictions.

---

## Team

| Member | Module | Scope |
|--------|--------|-------|
| Member 1 | `member1_risk_prediction` | Accident hotspot detection, ML risk prediction, real-time risk HUD |
| Member 2 | `member2_route_engine` | Safe route planning, A* safety ranking, offline maps |
| Member 3 | `member3_alert_system` | NLP alert generation, TTS, push notifications |
| Member 4 | `member4_driver_scoring` | Driver behavior monitoring, safety scoring, trip sessions |

---

## License

This project is for academic and research purposes.
