"""
NLP Alert Generation Engine — SafeNav Member 3
Generates explainable, context-aware, bilingual (English + Sinhala) safety
alerts by combining every available data dimension: accident cause, time of
day, day type, risk score, proximity, driver behaviour, vehicle type, and
hotspot statistics.
"""

from __future__ import annotations

from enum import Enum


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — ENUMS AND CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

class AlertSeverity(str, Enum):
    CRITICAL = "CRITICAL"   # risk_score >= 70 OR distance < 100 m
    WARNING  = "WARNING"    # risk_score 40–69 OR distance 100–250 m
    CAUTION  = "CAUTION"    # risk_score < 40 OR distance 250–400 m


class TimePeriod(str, Enum):
    LATE_NIGHT  = "Late Night"   # 00:00 – 05:59
    MORNING     = "Morning"      # 06:00 – 11:59
    AFTERNOON   = "Afternoon"    # 12:00 – 16:59
    EVENING     = "Evening"      # 17:00 – 19:59
    NIGHT       = "Night"        # 20:00 – 23:59


class DistanceZone(str, Enum):
    IMMEDIATE   = "immediate"    # < 100 m
    NEAR        = "near"         # 100–200 m
    APPROACHING = "approaching"  # 200–400 m


SEVERITY_COLORS: dict[str, str] = {
    "CRITICAL": "#FF3B5C",
    "WARNING":  "#FFB300",
    "CAUTION":  "#2979FF",
}

SEVERITY_ICONS: dict[str, str] = {
    "CRITICAL": "warning",
    "WARNING":  "error_outline",
    "CAUTION":  "info_outline",
}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def get_time_period(hour: int) -> TimePeriod:
    if 0 <= hour < 6:   return TimePeriod.LATE_NIGHT
    if 6 <= hour < 12:  return TimePeriod.MORNING
    if 12 <= hour < 17: return TimePeriod.AFTERNOON
    if 17 <= hour < 20: return TimePeriod.EVENING
    return TimePeriod.NIGHT


def get_distance_zone(distance_m: float) -> DistanceZone:
    if distance_m < 100: return DistanceZone.IMMEDIATE
    if distance_m < 200: return DistanceZone.NEAR
    return DistanceZone.APPROACHING


def get_alert_severity(risk_score: float, distance_m: float) -> AlertSeverity:
    if distance_m < 100:  return AlertSeverity.CRITICAL
    if risk_score >= 70:  return AlertSeverity.CRITICAL
    if risk_score >= 40:  return AlertSeverity.WARNING
    return AlertSeverity.CAUTION


def get_distance_phrase_en(distance_m: float) -> str:
    if distance_m < 100: return "immediately ahead"
    if distance_m < 200: return f"in {int(distance_m)}m"
    return f"approaching in {int(distance_m)}m"


def get_distance_phrase_si(distance_m: float) -> str:
    if distance_m < 100: return "ඉදිරියේම"
    if distance_m < 200: return f"{int(distance_m)}m ඉදිරියෙහි"
    return f"{int(distance_m)}m ලංවෙමින්"


def is_hotspot_night_heavy(hotspot: dict) -> bool:
    return hotspot.get("night_pct", 0) >= 40


def is_hotspot_weekend_heavy(hotspot: dict) -> bool:
    return hotspot.get("weekend_pct", 0) >= 45


def get_severity_prefix_en(severity: AlertSeverity) -> str:
    if severity == AlertSeverity.CRITICAL: return "⚠ DANGER"
    if severity == AlertSeverity.WARNING:  return "⚠ WARNING"
    return "⚠ CAUTION"


def get_severity_prefix_si(severity: AlertSeverity) -> str:
    if severity == AlertSeverity.CRITICAL: return "⚠ අනතුර"
    if severity == AlertSeverity.WARNING:  return "⚠ අවවාදය"
    return "⚠ ප්‍රවේශම්"


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — CAUSE-SPECIFIC MESSAGE BUILDERS
# Each function returns: {en, si, explanation_en, explanation_si}
# ═══════════════════════════════════════════════════════════════════════════════

def build_speeding_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en    = get_distance_phrase_en(distance_m)
    dist_si    = get_distance_phrase_si(distance_m)
    prefix_en  = get_severity_prefix_en(severity)
    prefix_si  = get_severity_prefix_si(severity)
    count      = hotspot["accident_count"]
    road       = hotspot["road_name"]
    night_pct  = hotspot.get("night_pct", 0)
    risk       = int(hotspot["risk_score"])

    if time_period in (TimePeriod.NIGHT, TimePeriod.LATE_NIGHT) and is_hotspot_night_heavy(hotspot):
        en = (
            f"{prefix_en}: Speeding hotspot {dist_en} — {road}. "
            f"{night_pct}% of {count} accidents here happen at night. "
            f"Reduce speed NOW."
        )
        si = (
            f"{prefix_si}: {dist_si} වේග හොට්ස්පොට් — {road}. "
            f"{count} අනතුරු වලින් {night_pct}% රාත්‍රියේ. "
            f"දැන් වේගය අඩු කරන්න."
        )
        explanation_en = (
            f"This is a night-time speeding hotspot with {count} recorded accidents. "
            f"Night conditions significantly increase the risk of speed-related collisions here."
        )
        explanation_si = (
            f"මෙය රාත්‍රී වේග හොට්ස්පොට් එකක් වන අතර {count} අනතුරු වාර්තා වී ඇත. "
            f"රාත්‍රී තත්ත්ව මෙහිදී වේග-සම්බන්ධ ගැටුම් අවදානම සැලකිය යුතු ලෙස වැඩි කරයි."
        )

    elif time_period == TimePeriod.MORNING:
        en = (
            f"{prefix_en}: Morning rush speeding zone {dist_en} — {road}. "
            f"{count} accidents recorded. Morning traffic increases collision risk."
        )
        si = (
            f"{prefix_si}: උදෑසන රථවාහන වේග කලාපය {dist_si} — {road}. "
            f"{count} අනතුරු. ප්‍රවේශමෙන් රිය පදවන්න."
        )
        explanation_en = (
            f"Morning peak hour traffic at {road} creates dangerous speeding conditions. "
            f"{count} accidents have been recorded at this location."
        )
        explanation_si = (
            f"{road} හි උදෑසන උච්ච පැය රථ ගමනාගමනය භයානක වේග තත්ත්ව ඇති කරයි. "
            f"{count} අනතුරු වාර්තා වී ඇත."
        )

    elif vehicle_type in ("Motorcycle", "Three Wheeler"):
        en = (
            f"{prefix_en}: High-risk speeding zone {dist_en} — {road}. "
            f"{count} accidents recorded. {vehicle_type}s are especially vulnerable here."
        )
        si = (
            f"{prefix_si}: ඉහළ අවදානම් කලාපය {dist_si}. "
            f"{count} අනතුරු. {vehicle_type} ඉතාම අවදානමට ලක්විය හැකිය."
        )
        explanation_en = (
            f"Two and three-wheelers face elevated risk at this speeding hotspot. "
            f"{count} accidents recorded at {road}. Maintain strict speed discipline."
        )
        explanation_si = (
            f"මෙම වේග හොට්ස්පොට් හිදී ද්විත්ව හා ත්‍රිත්ව රෝද රථ ඉහළ අවදානමකට මුහුණ දෙයි."
        )

    elif "overSpeeding" in driver_events:
        en = (
            f"{prefix_en}: You are OVERSPEEDING approaching a speeding hotspot "
            f"{dist_en} — {road}. {count} accidents here. REDUCE SPEED IMMEDIATELY."
        )
        si = (
            f"{prefix_si}: ඔබ අධිවේගයෙන් ගමන් කරමින් {dist_si} වේග හොට්ස්පොට් "
            f"ලංවෙමින් — {road}. {count} අනතුරු. වහාම වේගය අඩු කරන්න."
        )
        explanation_en = (
            f"CRITICAL: Your current speed exceeds safe limits AND you are approaching "
            f"a known speeding accident location ({count} incidents). Slow down immediately."
        )
        explanation_si = (
            f"තීරනාත්මක: ඔබේ වර්තමාන වේගය ආරක්ෂිත සීමාවන් ඉක්මවා ඇති අතර "
            f"ඔබ දන්නා වේග අනතුරු ස්ථානයකට ළංවෙමින් සිටී."
        )

    else:
        en = (
            f"{prefix_en}: Speeding accident hotspot {dist_en} — {road}. "
            f"Risk score {risk}/100. {count} accidents recorded. Maintain safe speed."
        )
        si = (
            f"{prefix_si}: {dist_si} වේග හොට්ස්පොට් — {road}. "
            f"අවදානම් ලකුණු {risk}/100. {count} අනතුරු. ආරක්ෂිත වේගය පවත්වා ගන්න."
        )
        explanation_en = (
            f"Speeding is the primary recorded cause of {count} accidents at {road}. "
            f"Risk score is {risk}/100. Obey speed limits strictly through this section."
        )
        explanation_si = (
            f"{road} හිදී {count} අනතුරු සඳහා වේගය මූලික සාධකය ලෙස වාර්තා වී ඇත. "
            f"අවදානම් ලකුණු {risk}/100."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_careless_driving_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en   = get_distance_phrase_en(distance_m)
    dist_si   = get_distance_phrase_si(distance_m)
    prefix_en = get_severity_prefix_en(severity)
    prefix_si = get_severity_prefix_si(severity)
    count     = hotspot["accident_count"]
    road      = hotspot["road_name"]
    risk      = int(hotspot["risk_score"])

    if is_weekend and is_hotspot_weekend_heavy(hotspot):
        en = (
            f"{prefix_en}: Weekend high-risk zone {dist_en} — {road}. "
            f"Weekend accidents are elevated here ({count} total). Stay completely focused."
        )
        si = (
            f"{prefix_si}: සති අන්ත ඉහළ අවදානම් කලාපය {dist_si}. "
            f"{count} අනතුරු. සම්පූර්ණ අවධානය යොමු කරන්න."
        )
        explanation_en = (
            f"Weekend traffic patterns significantly increase careless driving risk at {road}. "
            f"{count} accidents recorded, with weekend incidents disproportionately higher."
        )
        explanation_si = (
            f"සති අන්ත රථ ගමනාගමන රටා {road} හිදී නොසැලකිලිමත් රිය පැදවීමේ "
            f"අවදානම සැලකිය යුතු ලෙස වැඩි කරයි."
        )

    elif time_period == TimePeriod.EVENING:
        en = (
            f"{prefix_en}: Evening rush danger zone {dist_en} — {road}. "
            f"Careless driving peaks in evening traffic. {count} accidents recorded."
        )
        si = (
            f"{prefix_si}: සවස් රථ ගමනාගමන අවදානම් කලාපය {dist_si}. "
            f"සවස් රථ ගමනාගමනයේදී නොසැලකිලිමත් රිය පැදවීම ඉහළ යයි."
        )
        explanation_en = (
            f"Evening rush hour increases driver impatience and careless driving at {road}. "
            f"{count} accidents have occurred here, many during evening peak hours."
        )
        explanation_si = (
            f"සවස් රශ් ඔරලෝසු රියදුරු නොඉවසිලිමත්කම හා නොසැලකිලිමත් රිය පැදවීම "
            f"{road} හිදී වැඩි කරයි."
        )

    elif driver_score < 60:
        en = (
            f"{prefix_en}: Accident-prone area {dist_en} — {road}. "
            f"{count} accidents from careless driving. "
            f"Your safety score is low — drive with full attention."
        )
        si = (
            f"{prefix_si}: {dist_si} අනතුරු බහුල ප්‍රදේශය. {count} අනතුරු. "
            f"ඔබේ ආරක්ෂණ ලකුණු අඩුයි — සම්පූර්ණ අවධානයෙන් රිය පදවන්න."
        )
        explanation_en = (
            f"Your current safety score indicates risky driving patterns. "
            f"Combined with this careless driving hotspot ({count} incidents at {road}), "
            f"extreme caution is needed."
        )
        explanation_si = (
            f"ඔබේ වත්මන් ආරක්ෂණ ලකුණු අවදානම් රිය පැදවීමේ රටා පෙන්නුම් කරයි. "
            f"ප්‍රවේශමෙන් රිය පදවන්න."
        )

    else:
        en = (
            f"{prefix_en}: Careless driving hotspot {dist_en} — {road}. "
            f"Risk score {risk}/100. {count} accidents recorded. Full attention required."
        )
        si = (
            f"{prefix_si}: නොසැලකිලිමත් රිය පැදවීමේ හොට්ස්පොට් {dist_si}. "
            f"{count} අනතුරු. සම්පූර්ණ අවධානය අවශ්‍යයි."
        )
        explanation_en = (
            f"Careless driving causes the majority of accidents at {road} "
            f"({count} incidents, risk score {risk}/100). "
            f"Avoid distractions and stay completely focused."
        )
        explanation_si = (
            f"{road} හිදී අනතුරු බොහෝමයකට නොසැලකිලිමත් රිය පැදවීම හේතු වේ "
            f"({count} සිදුවීම්)."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_overtaking_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en   = get_distance_phrase_en(distance_m)
    dist_si   = get_distance_phrase_si(distance_m)
    prefix_en = get_severity_prefix_en(severity)
    prefix_si = get_severity_prefix_si(severity)
    count     = hotspot["accident_count"]
    road      = hotspot["road_name"]

    if time_period in (TimePeriod.NIGHT, TimePeriod.LATE_NIGHT):
        en = (
            f"{prefix_en}: NIGHT OVERTAKING DANGER {dist_en} — {road}. "
            f"Overtaking at night here has caused {count} accidents. "
            f"ABSOLUTELY DO NOT OVERTAKE."
        )
        si = (
            f"{prefix_si}: රාත්‍රී ඉදිරිය යාමේ අනතුර {dist_si}. "
            f"{count} රාත්‍රී අනතුරු. කිසිසේත් ඉදිරිය නොයන්න."
        )
        explanation_en = (
            f"Night-time overtaking at {road} is extremely dangerous with "
            f"{count} recorded accidents. Zero visibility and oncoming traffic "
            f"make overtaking here potentially fatal."
        )
        explanation_si = (
            f"{road} හිදී රාත්‍රී ඉදිරිය යාම {count} අනතුරු සමඟ අතිශය භයානකයි."
        )

    elif vehicle_type in ("Motorcycle", "Three Wheeler"):
        en = (
            f"{prefix_en}: DANGEROUS OVERTAKING ZONE {dist_en} — {road}. "
            f"{count} accidents here. {vehicle_type}s face extreme risk when overtaking. "
            f"Do NOT overtake."
        )
        si = (
            f"{prefix_si}: භයානක ඉදිරිය යාමේ කලාපය {dist_si}. "
            f"{count} අනතුරු. {vehicle_type} ඉදිරිය යාමේදී ඉතා අවදානමට ලක්වේ."
        )
        explanation_en = (
            f"Motorcycles and three-wheelers are disproportionately involved in "
            f"overtaking accidents at {road}. {count} incidents recorded. Never overtake here."
        )
        explanation_si = (
            f"මෝටර් සයිකල් හා ත්‍රිරෝද රථ {road} හිදී ඉදිරිය යාමේ අනතුරු සඳහා "
            f"අසමාන ලෙස සම්බන්ධ වේ."
        )

    elif time_period == TimePeriod.MORNING:
        en = (
            f"{prefix_en}: Morning rush overtaking hotspot {dist_en} — {road}. "
            f"{count} accidents from overtaking attempts. Stay in lane — do NOT overtake."
        )
        si = (
            f"{prefix_si}: උදෑසන ඉදිරිය යාමේ හොට්ස්පොට් {dist_si}. "
            f"{count} අනතුරු. පන්තියේ සිටින්න."
        )
        explanation_en = (
            f"Morning commuters frequently attempt dangerous overtaking at {road}, "
            f"causing {count} accidents. Patience is essential — never overtake here."
        )
        explanation_si = (
            f"උදෑසන ගමන්කරුවන් {road} හිදී නිතර භයානක ඉදිරිය යාමට උත්සාහ කරයි."
        )

    else:
        en = (
            f"{prefix_en}: OVERTAKING FORBIDDEN ZONE {dist_en} — {road}. "
            f"{count} overtaking accidents recorded. DO NOT attempt to overtake."
        )
        si = (
            f"{prefix_si}: ඉදිරිය යාම තහනම් කලාපය {dist_si}. "
            f"{count} අනතුරු. ඉදිරිය නොයන්න."
        )
        explanation_en = (
            f"Overtaking at {road} has directly caused {count} accidents. "
            f"This stretch has poor visibility or oncoming traffic making "
            f"overtaking extremely dangerous."
        )
        explanation_si = (
            f"{road} හිදී ඉදිරිය යාම {count} අනතුරු සඳහා සෘජුවම හේතු වී ඇත."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_fatigue_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en   = get_distance_phrase_en(distance_m)
    dist_si   = get_distance_phrase_si(distance_m)
    prefix_en = get_severity_prefix_en(severity)
    prefix_si = get_severity_prefix_si(severity)
    count     = hotspot["accident_count"]
    road      = hotspot["road_name"]
    night_pct = hotspot.get("night_pct", 0)

    if time_period == TimePeriod.LATE_NIGHT:
        en = (
            f"{prefix_en}: LATE NIGHT FATIGUE ZONE {dist_en} — {road}. "
            f"{night_pct}% of {count} accidents here occur late at night due to fatigue. "
            f"If you feel tired, STOP and rest."
        )
        si = (
            f"{prefix_si}: රාත්‍රී ගැඹුරු තෙහෙට්ටු කලාපය {dist_si}. "
            f"{count} අනතුරු. වෙහෙසට පත් නම් නවතා විවේකයක් ගන්න."
        )
        explanation_en = (
            f"Driver fatigue is extremely dangerous late at night. "
            f"{count} accidents have occurred at {road}, with {night_pct}% happening "
            f"in late-night hours. Pull over and rest if drowsy."
        )
        explanation_si = (
            f"රාත්‍රී ගැඹුරේ රියදුරු තෙහෙට්ටුව අතිශය භයානකයි. "
            f"{road} හිදී {count} අනතුරු සිදු වී ඇත."
        )

    elif time_period == TimePeriod.NIGHT:
        en = (
            f"{prefix_en}: Night fatigue hotspot {dist_en} — {road}. "
            f"{count} accidents from driver fatigue. Stay alert and focused on the road."
        )
        si = (
            f"{prefix_si}: රාත්‍රී තෙහෙට්ටු හොට්ස්පොට් {dist_si}. "
            f"{count} අනතුරු. අවදියෙන් සිටින්න."
        )
        explanation_en = (
            f"Night driving fatigue has caused {count} accidents at {road}. "
            f"If you are feeling tired, open a window, take a break, or switch drivers."
        )
        explanation_si = (
            f"රාත්‍රී රිය පැදවීමේ තෙහෙට්ටුව {road} හිදී {count} අනතුරු ඇති කර ඇත."
        )

    elif driver_score < 55:
        en = (
            f"{prefix_en}: Driver fatigue zone {dist_en} — {road}. "
            f"{count} fatigue accidents here. "
            f"Your driving score suggests reduced alertness. Take a break if needed."
        )
        si = (
            f"{prefix_si}: තෙහෙට්ටු කලාපය {dist_si}. {count} අනතුරු. "
            f"ඔබේ ලකුණු අඩු අවධානය පෙන්නුම් කරයි. අවශ්‍ය නම් නවතන්න."
        )
        explanation_en = (
            f"Your current driving score combined with this fatigue hotspot "
            f"({count} incidents at {road}) suggests risk. Consider taking a short break."
        )
        explanation_si = (
            f"ඔබේ වත්මන් රිය පැදවීමේ ලකුණු මෙම තෙහෙට්ටු හොට්ස්පොට් "
            f"({count} සිදුවීම්) සමඟ අවදානම පෙන්නුම් කරයි."
        )

    else:
        en = (
            f"{prefix_en}: Fatigue accident hotspot {dist_en} — {road}. "
            f"{count} accidents linked to driver fatigue. "
            f"Ensure you are well-rested and alert."
        )
        si = (
            f"{prefix_si}: තෙහෙට්ටු හොට්ස්පොට් {dist_si}. "
            f"{count} අනතුරු. ප්‍රමාණවත් විවේකයෙන් ගමන් කරන්න."
        )
        explanation_en = (
            f"Driver fatigue is the main cause of {count} accidents at {road}. "
            f"This is a long straight section where drowsiness frequently occurs."
        )
        explanation_si = (
            f"රියදුරු තෙහෙට්ටුව {road} හිදී {count} අනතුරු සඳහා ප්‍රධාන හේතුවයි."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_visibility_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en   = get_distance_phrase_en(distance_m)
    dist_si   = get_distance_phrase_si(distance_m)
    prefix_en = get_severity_prefix_en(severity)
    prefix_si = get_severity_prefix_si(severity)
    count     = hotspot["accident_count"]
    road      = hotspot["road_name"]
    night_pct = hotspot.get("night_pct", 0)

    if time_period in (TimePeriod.NIGHT, TimePeriod.LATE_NIGHT):
        en = (
            f"{prefix_en}: NIGHT VISIBILITY HAZARD {dist_en} — {road}. "
            f"{night_pct}% of {count} accidents here happen at night. "
            f"Switch on full headlights and slow down."
        )
        si = (
            f"{prefix_si}: රාත්‍රී දෘශ්‍යතා අනතුර {dist_si}. "
            f"{count} අනතුරු. සම්පූර්ණ හෙඩ්ලයිට් දල්වා වේගය අඩු කරන්න."
        )
        explanation_en = (
            f"Night-time visibility at {road} is severely reduced. "
            f"{night_pct}% of {count} recorded accidents occur at night here. "
            f"Full headlights, reduced speed, and increased following distance are essential."
        )
        explanation_si = (
            f"{road} හිදී රාත්‍රී දෘශ්‍යතාව බෙහෙවින් අඩුය. "
            f"{count} අනතුරු වලින් {night_pct}% රාත්‍රියේ සිදු වේ."
        )

    elif time_period == TimePeriod.MORNING:
        en = (
            f"{prefix_en}: Morning glare zone {dist_en} — {road}. "
            f"Sun glare reduces visibility and has caused {count} accidents here. "
            f"Use sun visor."
        )
        si = (
            f"{prefix_si}: උදෑසන හිරු දිළිසීමේ කලාපය {dist_si}. "
            f"{count} අනතුරු. හිරු ආවරණය භාවිතා කරන්න."
        )
        explanation_en = (
            f"Early morning sun glare at {road} has contributed to {count} accidents. "
            f"Lower your sun visor and reduce speed to compensate for reduced visibility."
        )
        explanation_si = (
            f"{road} හිදී උදෑසන හිරු දිළිසීම {count} අනතුරු සඳහා දායක වී ඇත."
        )

    else:
        en = (
            f"{prefix_en}: Low visibility zone {dist_en} — {road}. "
            f"{count} visibility-related accidents recorded. "
            f"Slow down and increase following distance."
        )
        si = (
            f"{prefix_si}: අඩු දෘශ්‍යතා කලාපය {dist_si}. "
            f"{count} අනතුරු. වේගය අඩු කර ඉදිරි රිය දුර වැඩි කරන්න."
        )
        explanation_en = (
            f"Visibility hazards at {road} have caused {count} accidents. "
            f"Poor lighting, road curves, or obstructions reduce sightlines. "
            f"Adjust your speed accordingly."
        )
        explanation_si = (
            f"{road} හිදී දෘශ්‍යතා අනතුරු {count} අනතුරු ඇති කර ඇත."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_out_of_control_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en   = get_distance_phrase_en(distance_m)
    dist_si   = get_distance_phrase_si(distance_m)
    prefix_en = get_severity_prefix_en(severity)
    prefix_si = get_severity_prefix_si(severity)
    count     = hotspot["accident_count"]
    road      = hotspot["road_name"]

    if time_period in (TimePeriod.NIGHT, TimePeriod.LATE_NIGHT):
        en = (
            f"{prefix_en}: NIGHT LOSS OF CONTROL ZONE {dist_en} — {road}. "
            f"{count} accidents from vehicle loss of control. "
            f"REDUCE SPEED — sharp bend or slippery surface ahead."
        )
        si = (
            f"{prefix_si}: රාත්‍රී රිය පාලන අහිමි කලාපය {dist_si}. "
            f"{count} අනතුරු. රිය ඉතාම සෙමෙන් පදවන්න."
        )
        explanation_en = (
            f"Drivers have lost vehicle control {count} times at {road} at night, "
            f"likely due to a sharp bend, poor road surface, or slippery conditions. "
            f"Reduce speed significantly."
        )
        explanation_si = (
            f"රාත්‍රියේ {road} හිදී රියදුරන් {count} වතාවක් රිය පාලනය නැති කර ගෙන ඇත."
        )

    elif "harshBraking" in driver_events or "sharpTurn" in driver_events:
        en = (
            f"{prefix_en}: Loss of control hotspot {dist_en} — {road}. "
            f"{count} accidents. Your recent sharp maneuvers increase your risk here. "
            f"Slow down immediately."
        )
        si = (
            f"{prefix_si}: රිය පාලන හොට්ස්පොට් {dist_si}. {count} අනතුරු. "
            f"ඔබේ මෑත තියුණු ක්‍රියාමාර්ග අවදානම වැඩි කරයි. දැන් සෙමෙන් යන්න."
        )
        explanation_en = (
            f"Your recent harsh braking or sharp turns combined with this "
            f"loss-of-control hotspot ({count} incidents) creates high collision risk. "
            f"Reduce speed and smooth your driving."
        )
        explanation_si = (
            f"ඔබේ මෑත ගැටීම් හෝ තියුණු හැරීම් මෙම රිය පාලන හොට්ස්පොට් "
            f"({count} සිදුවීම්) සමඟ ඉහළ ගැටුම් අවදානමක් ඇති කරයි."
        )

    elif vehicle_type == "Motorcycle":
        en = (
            f"{prefix_en}: MOTORCYCLE DANGER — Loss of control zone {dist_en} — {road}. "
            f"{count} accidents here. Motorcycles are at extreme risk. Reduce speed now."
        )
        si = (
            f"{prefix_si}: මෝටර් සයිකල් අනතුර — රිය පාලන කලාපය {dist_si}. "
            f"{count} අනතුරු. දැන් වේගය අඩු කරන්න."
        )
        explanation_en = (
            f"Motorcycle riders face extreme risk at this loss-of-control hotspot "
            f"at {road} ({count} accidents). "
            f"A sharp bend or road surface defect causes sudden loss of traction."
        )
        explanation_si = (
            f"මෝටර් සයිකල් රියදුරන් {road} හිදී රිය පාලන හොට්ස්පොට් "
            f"({count} අනතුරු) හිදී අතිශය අවදානමකට මුහුණ දෙයි."
        )

    else:
        en = (
            f"{prefix_en}: Vehicle control loss hotspot {dist_en} — {road}. "
            f"{count} accidents from loss of control. "
            f"REDUCE SPEED — hazardous road feature ahead."
        )
        si = (
            f"{prefix_si}: රිය පාලන හොට්ස්පොට් {dist_si}. "
            f"{count} අනතුරු. වේගය අඩු කරන්න."
        )
        explanation_en = (
            f"Drivers have lost vehicle control {count} times at {road}. "
            f"This may indicate a sharp bend, poor road surface, or dangerous junction "
            f"geometry. Reduce speed well in advance."
        )
        explanation_si = (
            f"රියදුරන් {road} හිදී {count} වතාවක් රිය පාලනය නැති කර ගෙන ඇත."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_vehicle_malfunction_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en   = get_distance_phrase_en(distance_m)
    dist_si   = get_distance_phrase_si(distance_m)
    prefix_en = get_severity_prefix_en(severity)
    prefix_si = get_severity_prefix_si(severity)
    count     = hotspot["accident_count"]
    road      = hotspot["road_name"]

    en = (
        f"{prefix_en}: Vehicle malfunction accident zone {dist_en} — {road}. "
        f"{count} accidents caused by vehicle failures here. "
        f"Check your vehicle before entering."
    )
    si = (
        f"{prefix_si}: රිය දෝෂ අනතුරු කලාපය {dist_si}. "
        f"{count} අනතුරු. රිය ශ්‍රේෂ්ඨ ලෙස ක්‍රියාත්මකදැයි සහතික කරන්න."
    )
    explanation_en = (
        f"Vehicle malfunctions including brake failure and tyre blowouts have caused "
        f"{count} accidents at {road}. "
        f"Ensure your vehicle is in proper working order. Watch for debris on the road."
    )
    explanation_si = (
        f"තිරිඟු අකාර්යක්ෂමතා ඇතුළු රිය දෝෂ {road} හිදී {count} අනතුරු ඇති කර ඇත."
    )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


def build_default_alert(
    hotspot: dict, distance_m: float, severity: AlertSeverity,
    time_period: TimePeriod, is_weekend: int, driver_score: int,
    driver_events: list[str], vehicle_type: str,
) -> dict:
    dist_en      = get_distance_phrase_en(distance_m)
    dist_si      = get_distance_phrase_si(distance_m)
    prefix_en    = get_severity_prefix_en(severity)
    prefix_si    = get_severity_prefix_si(severity)
    count        = hotspot["accident_count"]
    road         = hotspot["road_name"]
    risk         = int(hotspot["risk_score"])
    peak         = hotspot.get("peak_period", "unknown time")
    high_sev_pct = hotspot.get("high_sev_pct", 0)

    if severity == AlertSeverity.CRITICAL:
        en = (
            f"{prefix_en}: HIGHEST RISK ZONE {dist_en} — {road}. "
            f"Risk score {risk}/100. {count} accidents, {high_sev_pct}% serious or fatal. "
            f"Drive with EXTREME caution."
        )
        si = (
            f"{prefix_si}: ඉහළම අවදානම් කලාපය {dist_si}. "
            f"ලකුණු {risk}/100. {count} අනතුරු, {high_sev_pct}% බරපතළ. "
            f"ඉතා ප්‍රවේශමෙන් රිය පදවන්න."
        )
        explanation_en = (
            f"This is one of Panadura's highest-risk accident locations "
            f"(risk score {risk}/100). {count} accidents recorded with "
            f"{high_sev_pct}% classified as serious or fatal. "
            f"Most accidents occur during {peak}."
        )
        explanation_si = (
            f"මෙය පානදුරේ ඉහළම අවදානම් අනතුරු ස්ථාන වලින් එකකි "
            f"(ලකුණු {risk}/100). {count} අනතුරු, {high_sev_pct}% බරපතළ."
        )

    elif severity == AlertSeverity.WARNING:
        en = (
            f"{prefix_en}: Accident hotspot {dist_en} — {road}. "
            f"Risk score {risk}/100. {count} accidents recorded, mainly during {peak}. "
            f"Stay alert."
        )
        si = (
            f"{prefix_si}: අනතුරු හොට්ස්පොට් {dist_si}. "
            f"ලකුණු {risk}/100. {count} අනතුරු. අවදියෙන් සිටින්න."
        )
        explanation_en = (
            f"Historical data shows {count} accidents at {road} (risk score {risk}/100). "
            f"Peak accident time is {peak}. Maintain full attention through this section."
        )
        explanation_si = (
            f"ඓතිහාසික දත්ත {road} හිදී {count} අනතුරු පෙන්නුම් කරයි "
            f"(ලකුණු {risk}/100)."
        )

    else:
        en = (
            f"CAUTION: Accident-recorded area {dist_en} — {road}. "
            f"{count} accidents noted. Proceed carefully."
        )
        si = (
            f"ප්‍රවේශම්: {dist_si} අනතුරු ස්ථානය — {road}. "
            f"{count} අනතුරු. ප්‍රවේශමෙන් යන්න."
        )
        explanation_en = (
            f"Minor accident history at {road} ({count} incidents). "
            f"While risk is lower here, stay attentive to road conditions."
        )
        explanation_si = (
            f"{road} හිදී සුළු අනතුරු ඉතිහාසයක් ({count} සිදුවීම්)."
        )

    return {"en": en, "si": si, "explanation_en": explanation_en, "explanation_si": explanation_si}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — DRIVER BEHAVIOR CONTEXT APPENDER
# ═══════════════════════════════════════════════════════════════════════════════

def append_driver_context(
    explanation_en: str,
    explanation_si: str,
    driver_score: int,
    driver_events: list[str],
) -> tuple[str, str]:
    additions_en: list[str] = []
    additions_si: list[str] = []

    if driver_score < 40:
        additions_en.append(
            "⚠ Your safety score is critically low. "
            "Immediate improvement in driving behavior is required."
        )
        additions_si.append(
            "⚠ ඔබේ ආරක්ෂණ ලකුණු ඉතා අඩුයි. "
            "රිය පැදවීමේ හැසිරීම් වහාම වැඩිදියුණු කිරීම අවශ්‍යයි."
        )
    elif driver_score < 60:
        additions_en.append(
            "Your current safety score is below safe levels — extra caution is strongly advised."
        )
        additions_si.append(
            "ඔබේ වත්මන් ආරක්ෂණ ලකුණු ආරක්ෂිත මට්ටමට වඩා අඩුයි."
        )
    elif driver_score >= 85:
        additions_en.append(
            "You are driving well — maintain your safe driving habits through this zone."
        )
        additions_si.append(
            "ඔබ හොඳින් රිය පදවමින් සිටී — ආරක්ෂිත රිය පැදවීමේ පුරුදු දිගටම පවත්වා ගන්න."
        )

    if "overSpeeding" in driver_events:
        additions_en.append(
            "You have been overspeeding — reduce your speed before entering this zone."
        )
        additions_si.append(
            "ඔබ අධිවේගයෙන් ගමන් කර ඇත — මෙම කලාපයට ඇතුළු වීමට පෙර වේගය අඩු කරන්න."
        )

    if "harshBraking" in driver_events:
        additions_en.append(
            "Harsh braking detected — maintain a safe following distance to avoid sudden stops."
        )
        additions_si.append(
            "දැඩි ගේදොරු රොන්ද කිරීම හඳුනාගෙන ඇත — "
            "හදිසි නැවතීම් වළක්වා ගැනීමට ආරක්ෂිත රිය දුර පවත්වා ගන්න."
        )

    if "harshAcceleration" in driver_events:
        additions_en.append(
            "Rapid acceleration noted — smooth your acceleration through this accident zone."
        )
        additions_si.append(
            "ඉක්මන් ත්වරණය සටහන් කර ඇත — "
            "මෙම අනතුරු කලාපය හරහා ත්වරණය සුමට කරන්න."
        )

    if "sharpTurn" in driver_events:
        additions_en.append(
            "Sharp turns detected — reduce speed well before any turns in this area."
        )
        additions_si.append(
            "තියුණු හැරවීම් හඳුනාගෙන ඇත — "
            "මෙම ප්‍රදේශයේ ඕනෑම හැරවීමකට පෙර වේගය අඩු කරන්න."
        )

    if additions_en:
        explanation_en += " | " + " ".join(additions_en)
        explanation_si += " | " + " ".join(additions_si)

    return explanation_en, explanation_si


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — MAIN ALERT BUILDER (orchestrator)
# ═══════════════════════════════════════════════════════════════════════════════

_CAUSE_BUILDERS = {
    "Speeding":            build_speeding_alert,
    "Careless Driving":    build_careless_driving_alert,
    "Overtaking":          build_overtaking_alert,
    "Driver Fatigue":      build_fatigue_alert,
    "Bad Visibility":      build_visibility_alert,
    "Out of Control":      build_out_of_control_alert,
    "Vehicle Malfunction": build_vehicle_malfunction_alert,
}


def build_alert(
    hotspot: dict,
    distance_m: float,
    driver_score: int,
    driver_events: list[str],
    hour: int,
    is_weekend: int,
    vehicle_type: str = "Car",
) -> dict:
    time_period = get_time_period(hour)
    severity    = get_alert_severity(hotspot["risk_score"], distance_m)
    top_causes  = hotspot.get("top_causes") or []
    top_cause   = top_causes[0] if top_causes else "Unknown"

    builder  = _CAUSE_BUILDERS.get(top_cause, build_default_alert)
    messages = builder(
        hotspot=hotspot,
        distance_m=distance_m,
        severity=severity,
        time_period=time_period,
        is_weekend=is_weekend,
        driver_score=driver_score,
        driver_events=driver_events,
        vehicle_type=vehicle_type,
    )

    exp_en, exp_si = append_driver_context(
        messages["explanation_en"],
        messages["explanation_si"],
        driver_score,
        driver_events,
    )

    return {
        "hotspot_id":     hotspot["hotspot_id"],
        "severity":       severity.value,
        "alert_color":    SEVERITY_COLORS[severity.value],
        "alert_icon":     SEVERITY_ICONS[severity.value],
        "message_en":     messages["en"],
        "message_si":     messages["si"],
        "explanation_en": exp_en,
        "explanation_si": exp_si,
        "top_cause":      top_cause,
        "time_period":    time_period.value,
        "risk_score":     hotspot["risk_score"],
        "distance_m":     round(distance_m, 1),
        "road_name":      hotspot["road_name"],
        "accident_count": hotspot["accident_count"],
        "should_speak":   severity in (AlertSeverity.CRITICAL, AlertSeverity.WARNING),
        "driver_score":   driver_score,
    }


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — PRIORITY QUEUE
# ═══════════════════════════════════════════════════════════════════════════════

_SEVERITY_ORDER = {"CRITICAL": 0, "WARNING": 1, "CAUTION": 2}


def prioritize_alerts(alerts: list[dict]) -> list[dict]:
    sorted_alerts = sorted(
        alerts,
        key=lambda a: (_SEVERITY_ORDER.get(a["severity"], 3), a["distance_m"]),
    )
    return sorted_alerts[:2]
