import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _isAnnual = false;

  List<Map<String, dynamic>> get _plans => [
        {
          'name': 'Free',
          'price_monthly': 0,
          'price_annual': 0,
          'isPopular': false,
          'isCurrent': true,
          'buttonLabel': 'Current Plan',
          'buttonEnabled': false,
          'features': [
            'All hotspot markers on map',
            'Safety alerts near hotspots',
            'Basic route recommendation',
            'Driver safety score',
            'Google account login',
          ],
          'limitations': [
            'Trip history: last 7 days only',
            'No offline map',
            'No Sinhala voice alerts',
          ],
        },
        {
          'name': 'SafeNav Plus',
          'price_monthly': 350,
          'price_annual': 2800,
          'isPopular': true,
          'isCurrent': false,
          'buttonLabel': 'Upgrade to Plus',
          'buttonEnabled': true,
          'features': [
            'Everything in Free',
            'Offline map download',
            'Full trip history',
            'Detailed post-trip reports',
            'Priority alerts in high-risk zones',
            'Bilingual Sinhala voice alerts',
          ],
          'limitations': <String>[],
        },
        {
          'name': 'SafeNav Pro',
          'price_monthly': 990,
          'price_annual': 7900,
          'isPopular': false,
          'isCurrent': false,
          'buttonLabel': 'Upgrade to Pro',
          'buttonEnabled': true,
          'features': [
            'Everything in Plus',
            'Multi-driver dashboard',
            'Fleet safety reports',
            'CSV export of trip data',
            'API access for integration',
            'Priority support',
          ],
          'limitations': <String>[],
        },
      ];

  void _showUpgradeDialog(BuildContext context, String planName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Upgrade to $planName',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.rocket_launch_rounded,
              size: 48,
              color: Color(0xFF2979FF),
            ),
            const SizedBox(height: 12),
            Text(
              'In-app purchases are coming soon. '
              'We will notify you when $planName is available.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5C6B7A),
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFF2979FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isPopular = plan['isPopular'] as bool;
    final isCurrent = plan['isCurrent'] as bool;
    final priceMonthly = plan['price_monthly'] as int;
    final priceAnnual = plan['price_annual'] as int;
    final features = plan['features'] as List;
    final limitations = plan['limitations'] as List;
    final buttonEnabled = plan['buttonEnabled'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isPopular ? const Color(0xFF2979FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular
              ? Colors.transparent
              : isCurrent
                  ? const Color(0xFF2979FF).withOpacity(0.3)
                  : const Color(0xFFEEF1F5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? const Color(0xFF2979FF).withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: isPopular ? 24 : 8,
            offset: Offset(0, isPopular ? 8 : 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: name + badge + price ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Most Popular',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  plan['name'] as String,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isPopular
                        ? Colors.white
                        : const Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 8),
                if (priceMonthly == 0)
                  Text(
                    'Free forever',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isPopular
                          ? Colors.white
                          : const Color(0xFF0D1B2A),
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'LKR ${_isAnnual ? (priceAnnual ~/ 12) : priceMonthly}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: isPopular
                              ? Colors.white
                              : const Color(0xFF0D1B2A),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(
                          '/month',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPopular
                                ? Colors.white.withOpacity(0.7)
                                : const Color(0xFF5C6B7A),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_isAnnual && priceAnnual > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Billed as LKR $priceAnnual / year',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPopular
                            ? Colors.white.withOpacity(0.65)
                            : const Color(0xFFADB8C3),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────────
          Container(
            height: 0.5,
            color: isPopular
                ? Colors.white.withOpacity(0.15)
                : const Color(0xFFEEF1F5),
          ),

          // ── Features + limitations ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isPopular
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF2979FF)
                                    .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: isPopular
                                ? Colors.white
                                : const Color(0xFF2979FF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: isPopular
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF0D1B2A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...limitations.map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF1F5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.remove_rounded,
                            size: 11,
                            color: Color(0xFFADB8C3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l as String,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFADB8C3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── CTA button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: buttonEnabled
                    ? () => _showUpgradeDialog(
                        context, plan['name'] as String)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular
                      ? Colors.white
                      : isCurrent
                          ? const Color(0xFFF5F7FF)
                          : const Color(0xFF0D1B2A),
                  foregroundColor: isPopular
                      ? const Color(0xFF2979FF)
                      : isCurrent
                          ? const Color(0xFFADB8C3)
                          : Colors.white,
                  disabledBackgroundColor: isPopular
                      ? Colors.white.withOpacity(0.3)
                      : const Color(0xFFF5F7FF),
                  disabledForegroundColor: const Color(0xFFADB8C3),
                  elevation: 0,
                  side: (isCurrent && !isPopular)
                      ? const BorderSide(color: Color(0xFFDDE3EA))
                      : BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  plan['buttonLabel'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF2979FF), size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Plans & Billing',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D1B2A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: const Color(0xFFEEF1F5)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current plan banner ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A0E21), Color(0xFF1A2A4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Plan',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Free',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Upgrade for more features',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2979FF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF2979FF),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Monthly / Annual toggle ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Monthly',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: !_isAnnual
                          ? const Color(0xFF0D1B2A)
                          : const Color(0xFFADB8C3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _isAnnual = !_isAnnual),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 52,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _isAnnual
                            ? const Color(0xFF2979FF)
                            : const Color(0xFFDDE3EA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        alignment: _isAnnual
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Annual',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _isAnnual
                          ? const Color(0xFF0D1B2A)
                          : const Color(0xFFADB8C3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: _isAnnual ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C06A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Save 33%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pricing cards ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: _plans.map(_buildPlanCard).toList(),
              ),
            ),

            // ── Bottom note ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      'All plans include a 7-day free trial',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF5C6B7A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cancel anytime · No hidden fees',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFFADB8C3)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2979FF),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(
                              color: Color(0xFFADB8C3), fontSize: 11),
                        ),
                        GestureDetector(
                          child: const Text(
                            'Terms of Service',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2979FF),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
