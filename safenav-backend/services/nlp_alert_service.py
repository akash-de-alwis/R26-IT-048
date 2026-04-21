"""
NLP Alert Service — Member 3 Part 1
Generates context-aware, explainable safety alerts by combining
hotspot risk data with the driver's live behaviour.
"""

from __future__ import annotations

# ── Section A: Alert templates ────────────────────────────────────────────────

TEMPLATES: dict[str, list[dict]] = {
    "Speeding": [
        {
            "condition": "night",
            "severity": "CRITICAL",
            "en": (
                "⚠ DANGER: Night speeding hotspot in {distance}m. "
                "{count} accidents here, {night_pct}% at night. "
                "Reduce speed immediately."
            ),
            "si": (
                "⚠ අනතුර: රාත්‍රී වේගය හොට්ස්පොට් {distance}m ඇතුළත. "
                "{count} අනතුරු, {night_pct}% රාත්‍රියේ. "
                "වහාම වේගය අඩු කරන්න."
            ),
            "explanation": (
                "This junction has a high night-time speeding accident rate "
                "based on {count} recorded incidents."
            ),
        },
        {
            "condition": "default",
            "severity": "WARNING",
            "en": (
                "⚠ Speeding hotspot ahead in {distance}m. "
                "{count} accidents recorded at {road}. "
                "Maintain safe speed."
            ),
            "si": (
                "⚠ වේග හොට්ස්පොට් {distance}m ඉදිරියෙහි. "
                "{road} හි {count} අනතුරු. "
                "ආරක්ෂිත වේගයක් පවත්වා ගන්න."
            ),
            "explanation": (
                "Speeding is the primary cause of accidents at this location "
                "({count} total incidents)."
            ),
        },
    ],

    "Careless Driving": [
        {
            "condition": "weekend",
            "severity": "WARNING",
            "en": (
                "⚠ High-risk zone in {distance}m. "
                "Weekend accident rate is elevated here. "
                "{count} incidents recorded. Stay focused."
            ),
            "si": (
                "⚠ {distance}m තුළ ඉහළ අවදානම් කලාපය. "
                "සති අන්ත අනතුරු අනුපාතය ඉහළයි. "
                "{count} සිදුවීම් ."
            ),
            "explanation": (
                "Weekend traffic patterns increase careless driving risk "
                "at this junction ({count} accidents recorded)."
            ),
        },
        {
            "condition": "default",
            "severity": "WARNING",
            "en": (
                "⚠ Caution: Accident-prone area in {distance}m. "
                "Careless driving caused {count} accidents here. Stay alert."
            ),
            "si": (
                "⚠ ප්‍රවේශම්: {distance}m තුළ අනතුරු බහුල ප්‍රදේශය. "
                "නොසැලකිලිමත් රිය පැදවීම {count} අනතුරු ඇති කළේය."
            ),
            "explanation": (
                "Careless driving is the leading cause of accidents at {road}. "
                "Extra attention required."
            ),
        },
    ],

    "Overtaking": [
        {
            "condition": "default",
            "severity": "CRITICAL",
            "en": (
                "⚠ DANGER: Unsafe overtaking zone in {distance}m. "
                "{count} accidents from overtaking. "
                "Do NOT overtake here."
            ),
            "si": (
                "⚠ අනතුර: {distance}m තුළ අනාරක්ෂිත ඉදිරිය යාමේ කලාපය. "
                "ඉදිරිය යාමෙන් {count} අනතුරු. "
                "මෙහිදී ඉදිරිය නොයන්න."
            ),
            "explanation": (
                "Overtaking at this location is extremely dangerous — "
                "{count} accidents recorded due to overtaking attempts."
            ),
        },
    ],

    "Driver Fatigue": [
        {
            "condition": "night",
            "severity": "CRITICAL",
            "en": (
                "⚠ FATIGUE ZONE: Driver fatigue hotspot in {distance}m. "
                "{count} late-night accidents here. "
                "Take a break if tired."
            ),
            "si": (
                "⚠ තෙහෙට්ටු කලාපය: {distance}m තුළ රියදුරු තෙහෙට්ටුව හොට්ස්පොට්. "
                "{count} රාත්‍රී අනතුරු. "
                "වෙහෙසට පත්ව නම් විවේකයක් ගන්න."
            ),
            "explanation": (
                "Driver fatigue accidents peak at night at this location. "
                "{count} incidents recorded, mostly late night."
            ),
        },
        {
            "condition": "default",
            "severity": "WARNING",
            "en": (
                "⚠ Driver fatigue hotspot in {distance}m. "
                "{count} accidents linked to fatigue here. "
                "Stay alert and focused."
            ),
            "si": (
                "⚠ {distance}m තුළ රියදුරු තෙහෙට්ටු හොට්ස්පොට්. "
                "{count} අනතුරු. අවදියෙන් සිටින්න."
            ),
            "explanation": (
                "Fatigue-related accidents frequently occur here. "
                "Ensure you are well-rested before this stretch."
            ),
        },
    ],

    "Bad Visibility": [
        {
            "condition": "night",
            "severity": "CRITICAL",
            "en": (
                "⚠ LOW VISIBILITY ZONE in {distance}m. "
                "Night visibility accidents common here ({count} incidents). "
                "Use headlights and slow down."
            ),
            "si": (
                "⚠ රාත්‍රී දෘශ්‍යතා කලාපය {distance}m තුළ. "
                "{count} සිදුවීම්. "
                "හෙඩ්ලයිට් භාවිතා කර වේගය අඩු කරන්න."
            ),
            "explanation": (
                "Poor night-time visibility at this junction has caused "
                "{count} accidents. Headlights and reduced speed are critical."
            ),
        },
        {
            "condition": "default",
            "severity": "WARNING",
            "en": (
                "⚠ Visibility hazard zone in {distance}m. "
                "{count} visibility-related accidents at {road}. "
                "Drive carefully."
            ),
            "si": (
                "⚠ {distance}m තුළ දෘශ්‍යතා අවදානම් කලාපය. "
                "{count} අනතුරු. ප්‍රවේශමෙන් රිය පදවන්න."
            ),
            "explanation": (
                "Reduced visibility conditions have caused "
                "{count} accidents at this location."
            ),
        },
    ],

    "Out of Control": [
        {
            "condition": "default",
            "severity": "CRITICAL",
            "en": (
                "⚠ DANGER: Vehicle control loss hotspot in {distance}m. "
                "{count} accidents from loss of control. "
                "Reduce speed NOW."
            ),
            "si": (
                "⚠ අනතුර: {distance}m තුළ රිය පාලනය නැතිවීමේ හොට්ස්පොට්. "
                "{count} අනතුරු. දැන් වේගය අඩු කරන්න."
            ),
            "explanation": (
                "Drivers have lost vehicle control {count} times at this spot "
                "— sharp bend or road surface issue suspected."
            ),
        },
    ],

    "default": [
        {
            "condition": "high_risk",
            "severity": "CRITICAL",
            "en": (
                "⚠ HIGH RISK ZONE in {distance}m: {road}. "
                "Risk score {risk_score}/100. "
                "{count} accidents recorded. Drive with extreme caution."
            ),
            "si": (
                "⚠ ඉහළ අවදානම් කලාපය {distance}m තුළ: {road}. "
                "අවදානම් ලකුණු {risk_score}/100. "
                "{count} අනතුරු."
            ),
            "explanation": (
                "This is one of the highest-risk locations in Panadura with a "
                "risk score of {risk_score}/100 based on {count} recorded accidents."
            ),
        },
        {
            "condition": "default",
            "severity": "CAUTION",
            "en": (
                "Caution: Accident hotspot in {distance}m at {road}. "
                "{count} accidents recorded. Stay alert."
            ),
            "si": (
                "ප්‍රවේශම්: {distance}m තුළ අනතුරු හොට්ස්පොට්. "
                "{count} අනතුරු. අවදියෙන් සිටින්න."
            ),
            "explanation": (
                "Historical accident data shows {count} incidents at this location. "
                "Proceed with caution."
            ),
        },
    ],
}

_SEVERITY_ORDER = {"CRITICAL": 0, "WARNING": 1, "CAUTION": 2}
_SEVERITY_COLOR = {
    "CRITICAL": "#FF3B5C",
    "WARNING":  "#FFB300",
    "CAUTION":  "#2979FF",
}


# ── Section B: Context selector ───────────────────────────────────────────────

def is_night(hour: int) -> bool:
    return hour < 6 or hour >= 20


def select_template(
    cause: str,
    hotspot: dict,
    hour: int,
    is_weekend: int,
) -> dict:
    """Return the first template variant whose condition matches the context."""
    variants = TEMPLATES.get(cause) or TEMPLATES["default"]

    active_conditions: list[str] = []
    if is_night(hour):
        active_conditions.append("night")
    if is_weekend == 1:
        active_conditions.append("weekend")
    if hotspot.get("risk_score", 0) >= 70:
        active_conditions.append("high_risk")
    active_conditions.append("default")

    for condition in active_conditions:
        for variant in variants:
            if variant["condition"] == condition:
                return variant

    # Guaranteed fallback
    return TEMPLATES["default"][-1]


# ── Section C: Alert builder ──────────────────────────────────────────────────

def build_alert(
    hotspot: dict,
    distance_m: float,
    driver_score: int,
    driver_events: list[str],
    hour: int,
    is_weekend: int,
) -> dict:
    """Build a complete, explainable alert dict for one hotspot."""
    top_causes: list[str] = hotspot.get("top_causes") or []
    top_cause = top_causes[0] if top_causes else "Unknown"

    template = select_template(top_cause, hotspot, hour, is_weekend)

    placeholders = {
        "distance":   int(distance_m),
        "count":      hotspot.get("accident_count", 0),
        "road":       hotspot.get("road_name", "this location"),
        "night_pct":  hotspot.get("night_pct", 0),
        "risk_score": int(hotspot.get("risk_score", 0)),
    }

    def fill(text: str) -> str:
        try:
            return text.format(**placeholders)
        except KeyError:
            return text

    message_en  = fill(template["en"])
    message_si  = fill(template["si"])
    explanation = fill(template["explanation"])

    # Driver behaviour context appended to explanation
    if driver_score < 60:
        explanation += " Your current driving score is low — extra caution needed."
    if "harshBraking" in driver_events:
        explanation += " Harsh braking detected — maintain safe following distance."
    if "overSpeeding" in driver_events:
        explanation += " You have been overspeeding — reduce speed now."

    severity = template["severity"]

    return {
        "hotspot_id":  hotspot["hotspot_id"],
        "severity":    severity,
        "message_en":  message_en,
        "message_si":  message_si,
        "explanation": explanation,
        "top_cause":   top_cause,
        "risk_score":  float(hotspot.get("risk_score", 0)),
        "distance_m":  round(distance_m, 1),
        "road_name":   hotspot.get("road_name", ""),
        "should_speak": severity in ("CRITICAL", "WARNING"),
        "alert_color": _SEVERITY_COLOR.get(severity, "#2979FF"),
    }


# ── Section D: Priority queue ─────────────────────────────────────────────────

def prioritize_alerts(alerts: list[dict]) -> list[dict]:
    """Sort by severity then distance; return at most 2."""
    sorted_alerts = sorted(
        alerts,
        key=lambda a: (
            _SEVERITY_ORDER.get(a["severity"], 99),
            a["distance_m"],
        ),
    )
    return sorted_alerts[:2]
