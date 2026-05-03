# SafeNav - Accident Risk Navigation App

A mobile application that helps drivers navigate safely by detecting accident hotspots, providing risk-aware routing, monitoring driver behavior, and delivering real-time safety alerts. Developed for the Panadura, Sri Lanka road network.

---

## Features

### Accident Hotspot Visualization
- Map overlay of accident-prone locations with color-coded risk levels
- Nearby hotspot detection within a configurable radius (300–400 m)
- Real-time risk scoring based on location, time of day, weather context, and vehicle type

### Safe Route Planning
- A\*-algorithm-based route safety ranking with three modes: **Safest**, **Balanced**, **Fastest**
- Integration with Mapbox Directions API for real road geometry
- Side-by-side route comparison showing safety scores for each alternative

### Real-Time Safety Alerts
- Proximity-triggered alerts every 5 seconds while driving
- NLP-generated contextual warnings in **English and Sinhala**
- Text-to-speech voice announcements for hands-free awareness
- Alert prioritization based on driver behavior and environmental context
- Tap any alert card to open a full detail sheet (renders above the navigation bar via root navigator)

### Driver Safety Scoring
- Live safety score (0–100) using onboard accelerometer and gyroscope
- Detects harsh braking (−8 pts), harsh acceleration (−5 pts), sharp turns (−4 pts), and overspeeding >70 km/h (−6 pts)
- Smooth driving earns +2 pts per interval
- Trip session tracking with full event history and score gauge visualization

---

## Tech Stack

### Mobile App (Flutter)
| Package | Purpose |
|---|---|
| `mapbox_maps_flutter ^2.4.0` | Interactive map rendering |
| `geolocator ^12.0.0` | GPS location tracking |
| `sensors_plus ^6.0.0` | Accelerometer & gyroscope |
| `flutter_tts ^4.0.2` | Text-to-speech alerts |
| `provider ^6.1.2` | State management |
| `go_router ^14.0.0` | Tab-based navigation |
| `http ^1.2.2` | REST API client |

### Backend (Python / FastAPI)
| Package | Purpose |
|---|---|
| `fastapi 0.111.0` | REST API framework |
| `uvicorn 0.29.0` | ASGI server |
| `scikit-learn 1.4.2` | ML risk prediction model |
| `pandas / numpy` | Data processing |
| `pydantic 2.7.1` | Request/response validation |

---

## Architecture

```
accident mobile app v3/
├── safenav/                        # Flutter mobile application
│   └── lib/
│       ├── main.dart               # Entry point, permissions, Mapbox init
│       ├── app.dart                # Router & bottom navigation shell
│       ├── core/
│       │   └── providers/          # AppProvider, AlertService, SensorService
│       ├── member1_hotspots/       # Hotspot map UI & risk overlay
│       ├── member2_routing/        # Route planning & comparison screens
│       ├── member3_alerts/         # Alert display & TTS integration
│       └── member4_scoring/        # Driver score gauge & trip events
│
└── safenav-backend/                # Python FastAPI backend
    ├── main.py                     # All API route definitions
    ├── member1_risk/               # Hotspot & ML risk inference service
    ├── member2_routing/            # A* route safety ranking service
    ├── member3_alerts/             # NLP alert generation service
    ├── models/                     # Pydantic schemas
    ├── risk_model.pkl              # Pre-trained scikit-learn model
    └── hotspot_risk_scores.json    # Precomputed hotspot dataset
```

**State management:** Provider (ChangeNotifier pattern)  
**Navigation:** Go Router with indexed shell route for tab persistence

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Server health check |
| `GET` | `/hotspots` | All accident hotspots with risk scores |
| `GET` | `/hotspots/near?lat=&lng=&radius_m=300` | Hotspots within radius |
| `GET` | `/hotspots/{id}` | Single hotspot details |
| `POST` | `/route/safety` | Rank route alternatives by safety score |
| `POST` | `/predict/realtime` | Real-time ML risk prediction |
| `POST` | `/alerts/nearby` | NLP-generated alerts for nearby hotspots |

The backend runs on `http://localhost:8000` (Android emulator: `http://10.0.2.2:8000`).

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.x
- Python 3.10+
- A [Mapbox](https://www.mapbox.com/) account and public access token
- Android Studio / Xcode for device emulation

### Backend Setup

```bash
cd safenav-backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Mobile App Setup

1. Add your Mapbox token to `safenav/assets/` or the relevant config file.
2. Install dependencies:
   ```bash
   cd safenav
   flutter pub get
   ```
3. Run on a connected device or emulator:
   ```bash
   flutter run
   ```

> **Note:** Location and sensor permissions are requested at runtime. Ensure the backend is reachable from your device/emulator before launching.

---

## ML Model

The risk prediction model (`risk_model.pkl`) is a scikit-learn classifier trained on historical accident data for the Panadura region. It takes the following features as input:

- Geographic coordinates (latitude, longitude)
- Temporal features: hour, day of week, month, is_night, is_weekend
- Vehicle type (motorcycle, car, bus, etc.)

---

## Team

This project was built collaboratively with module-based responsibilities:

| Member | Module |
|--------|--------|
| Member 1 | Accident hotspot detection & risk prediction |
| Member 2 | Safe route planning & A* ranking |
| Member 3 | Real-time NLP alert generation |
| Member 4 | Driver behavior monitoring & safety scoring |

---

## License

This project is for academic and research purposes.
