import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/realtime_risk_service.dart';
import './risk_detail_sheet.dart';

class RealtimeRiskHUD extends StatelessWidget {
  const RealtimeRiskHUD({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeRiskService>(
      builder: (ctx, service, _) {
        final risk = service.currentRisk;
        if (risk == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => RiskDetailSheet(risk: risk),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: risk.riskColor.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: risk.riskColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Risk score circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: risk.riskColor.withOpacity(0.12),
                    border: Border.all(color: risk.riskColor, width: 2.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          risk.riskScore.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: risk.riskColor,
                            height: 1,
                          ),
                        ),
                        Text(
                          'risk',
                          style: TextStyle(
                            fontSize: 8,
                            color: risk.riskColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: risk.riskColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              risk.riskLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(risk.weather.icon,
                              size: 14, color: const Color(0xFF5C6B7A)),
                          const SizedBox(width: 4),
                          Text(
                            '${risk.weather.temperatureC.toStringAsFixed(0)}°C',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5C6B7A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        risk.recommendation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0D1B2A),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFFADB8C3)),
              ],
            ),
          ),
        );
      },
    );
  }
}
