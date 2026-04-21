from __future__ import annotations

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from models.schemas import (
    HealthResponse,
    HotspotResponse,
    RealTimeRiskRequest,
    RealTimeRiskResponse,
    RouteSafetyRequest,
    RouteSafetyResponse,
)
from services import hotspot_service, risk_service, route_service

app = FastAPI(
    title="SafeNav API",
    version="1.0.0",
    description="Road accident risk prediction API for Panadura, Sri Lanka",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── 1. Root ───────────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"message": "SafeNav API is running", "docs": "/docs"}


# ── 2. Health ─────────────────────────────────────────────────────────────────

@app.get("/health", response_model=HealthResponse)
def health():
    return HealthResponse(
        status="ok",
        model_loaded=risk_service.MODEL is not None,
        hotspots_loaded=len(hotspot_service.HOTSPOTS),
    )


# ── 3. All hotspots ───────────────────────────────────────────────────────────

@app.get(
    "/hotspots",
    response_model=list[HotspotResponse],
    description="Returns all accident hotspots with risk scores for map display",
)
def list_hotspots(risk_level: str | None = Query(default=None)):
    hotspots = hotspot_service.get_all_hotspots()
    if risk_level:
        level = risk_level.upper()
        hotspots = [h for h in hotspots if h["risk_level"] == level]
    return hotspots


# ── 4. Hotspots near a GPS point (must come before /{hotspot_id}) ─────────────

@app.get("/hotspots/near", response_model=list[HotspotResponse])
def hotspots_near(
    lat: float = Query(...),
    lng: float = Query(...),
    radius_m: float = Query(default=300),
):
    return hotspot_service.get_hotspots_near_point(lat, lng, radius_m)


# ── 5. Single hotspot by ID ───────────────────────────────────────────────────

@app.get("/hotspots/{hotspot_id}", response_model=HotspotResponse)
def get_hotspot(hotspot_id: int):
    hotspot = hotspot_service.get_hotspot_by_id(hotspot_id)
    if hotspot is None:
        raise HTTPException(status_code=404, detail=f"Hotspot {hotspot_id} not found")
    return hotspot


# ── 6. Route safety ranking ───────────────────────────────────────────────────

@app.post("/route/safety", response_model=RouteSafetyResponse)
def route_safety(body: RouteSafetyRequest):
    result = route_service.rank_routes(
        origin=body.origin.model_dump(),
        destination=body.destination.model_dump(),
        destination_name=body.destination_name,
    )
    return result


# ── 7. Real-time risk prediction ──────────────────────────────────────────────

@app.post("/predict/realtime", response_model=RealTimeRiskResponse)
def predict_realtime(body: RealTimeRiskRequest):
    request_data = body.model_dump()

    prediction = risk_service.predict_risk(request_data)

    nearby = hotspot_service.get_hotspots_near_point(body.latitude, body.longitude, radius_m=300)
    nearest = nearby[0] if nearby else None

    alert_en, alert_si = risk_service.generate_alert(
        prediction["risk_level"],
        nearest,
        body.hour,
        body.vehicle_type,
    )

    return RealTimeRiskResponse(
        risk_probability=prediction["risk_probability"],
        risk_score=prediction["risk_score"],
        risk_level=prediction["risk_level"],
        nearest_hotspot_id=nearest["hotspot_id"] if nearest else None,
        nearest_hotspot_distance_m=nearest["distance_m"] if nearest else None,
        alert_message=alert_en,
        alert_message_si=alert_si,
        should_alert=prediction["risk_level"] in ("HIGH", "MEDIUM"),
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
