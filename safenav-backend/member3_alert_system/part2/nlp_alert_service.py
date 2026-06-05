"""
Bilingual obstacle alert message generator.
Uses templated NLP with severity-aware tone.
This is INDEPENDENT of Member 3 Part 1's NLP system — built
specifically for obstacle alerts in Part 2.
"""
from .schemas import ObstacleType, ObstacleSeverity, ObstacleAlertText

def build_alert_text(
    obs_type: ObstacleType,
    severity: ObstacleSeverity,
    metric_value: float = None,
    metric_unit: str = None,
) -> ObstacleAlertText:

    metric_text_en = ""
    metric_text_si = ""
    if metric_value is not None:
        if metric_unit == 'degrees':
            metric_text_en = f" of {int(metric_value)} degrees"
            metric_text_si = f" අංශක {int(metric_value)}ක"
        elif metric_unit == 'percent':
            metric_text_en = f" at {metric_value:.0f}% grade"
            metric_text_si = f" {metric_value:.0f}% බෑවුමක්"

    sev_prefix_en = {
        ObstacleSeverity.CRITICAL: "Caution! Critical",
        ObstacleSeverity.WARNING:  "Warning,",
        ObstacleSeverity.CAUTION:  "Be aware,",
    }[severity]

    sev_prefix_si = {
        ObstacleSeverity.CRITICAL: "අවදානයි! බරපතල",
        ObstacleSeverity.WARNING:  "අවධානයෙන් සිටින්න,",
        ObstacleSeverity.CAUTION:  "සැලකිලිමත් වන්න,",
    }[severity]

    type_data = {
        ObstacleType.SHARP_BEND: {
            'short_en': f"Sharp bend ahead{metric_text_en}",
            'short_si': f"ඉදිරියේ තියුණු වංගුවක්{metric_text_si}",
            'voice_en': f"{sev_prefix_en} sharp bend ahead. Reduce speed before entering the turn.",
            'voice_si': f"{sev_prefix_si} තියුණු වංගුවක් ඉදිරියේ ඇත. වංගුවට පෙර වේගය අඩු කරන්න.",
        },
        ObstacleType.STEEP_SLOPE: {
            'short_en': f"Steep slope ahead{metric_text_en}",
            'short_si': f"ඉදිරියේ පැත්ත අසලින්{metric_text_si}",
            'voice_en': f"{sev_prefix_en} steep slope ahead. Use lower gears and maintain control.",
            'voice_si': f"{sev_prefix_si} ඉදිරියේ පැත්ත අසලින් ඇත. ක්‍රමානුකූල ගියර්වලින් රිය පදවන්න.",
        },
        ObstacleType.NARROW_ROAD: {
            'short_en': "Narrow road segment ahead",
            'short_si': "ඉදිරියේ පටු මාර්ග කොටසක්",
            'voice_en': "Narrow road ahead. Drive slowly and watch for oncoming traffic.",
            'voice_si': "ඉදිරියේ පටු මාර්ගයක් ඇත. සෙමින් රිය පදවා ප්‍රතිවිරුද්ධ දිශාවට ඇති වාහන පිළිබඳ අවධානයෙන් සිටින්න.",
        },
        ObstacleType.INTERSECTION: {
            'short_en': "Major intersection ahead",
            'short_si': "ඉදිරියේ ප්‍රධාන හන්දියක්",
            'voice_en': f"{sev_prefix_en} major intersection ahead. Check all directions and yield as needed.",
            'voice_si': f"{sev_prefix_si} ප්‍රධාන හන්දියක් ඉදිරියේ ඇත. සියලු දිශාවන් පරීක්ෂා කර අවශ්‍ය නම් මඟ දෙන්න.",
        },
        ObstacleType.SPEED_BUMP: {
            'short_en': "Speed bump ahead",
            'short_si': "ඉදිරියේ වේග බාධකයක්",
            'voice_en': "Speed bump ahead. Slow down.",
            'voice_si': "ඉදිරියේ වේග බාධකයක් ඇත. වේගය අඩු කරන්න.",
        },
        ObstacleType.BARRIER: {
            'short_en': "Barrier or gate ahead",
            'short_si': "ඉදිරියේ බාධකයක් හෝ ගේට්ටුවක්",
            'voice_en': "Barrier or gate ahead. Prepare to stop.",
            'voice_si': "ඉදිරියේ බාධකයක් හෝ ගේට්ටුවක් ඇත. නැවැත්වීමට සූදානම් වන්න.",
        },
        ObstacleType.CROSSING: {
            'short_en': "Pedestrian crossing ahead",
            'short_si': "ඉදිරියේ පදිකයන් මාරුවන තැනක්",
            'voice_en': "Pedestrian crossing ahead. Watch for people on the road.",
            'voice_si': "ඉදිරියේ පදිකයන් මාරුවන තැනක් ඇත. මාර්ගයේ සිටින පුද්ගලයන් පිළිබඳ අවධානයෙන් සිටින්න.",
        },
        ObstacleType.USER_REPORTED: {
            'short_en': "Driver-reported hazard ahead",
            'short_si': "රියදුරෙකු වාර්තා කළ අවදානමක්",
            'voice_en': "A hazard has been reported on this road by another driver. Drive carefully.",
            'voice_si': "තවත් රියදුරෙකු විසින් මෙම මාර්ගයේ අවදානමක් වාර්තා කර ඇත. ප්‍රවේශමෙන් රිය පදවන්න.",
        },
    }

    d = type_data.get(obs_type, type_data[ObstacleType.USER_REPORTED])
    return ObstacleAlertText(
        short_en=d['short_en'],
        short_si=d['short_si'],
        voice_en=d['voice_en'],
        voice_si=d['voice_si'])
