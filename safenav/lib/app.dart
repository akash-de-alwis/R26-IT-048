import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'member3_alerts/services/alert_service.dart';
import 'member3_alerts/widgets/safety_alert_card.dart';
import 'shared/screens/home_screen.dart';
import 'shared/screens/driver_score_screen.dart';
import 'shared/screens/profile_screen.dart';
import 'shared/widgets/bottom_nav_bar.dart';

final _router = GoRouter(
  initialLocation: AppConstants.routeHome,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return _AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeHome,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeScore,
              builder: (context, state) => const DriverScoreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeProfile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class SafeNavApp extends StatelessWidget {
  const SafeNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const _AppShell({required this.navigationShell});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  AlertService? _alertService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = context.read<AlertService>();
    if (_alertService == null) {
      _alertService = svc;
      _alertService!.addListener(_onAlertsChanged);
    }
  }

  @override
  void dispose() {
    _alertService?.removeListener(_onAlertsChanged);
    super.dispose();
  }

  void _onAlertsChanged() {
    if (!mounted) return;
    setState(() {});

    final alerts = _alertService?.activeAlerts ?? [];
    if (alerts.isEmpty) return;

    final alert = alerts.first;
    final severity = alert['severity'] as String? ?? 'CAUTION';
    final message = alert['message_en'] as String? ?? 'Safety alert nearby';
    final color = switch (severity) {
      'CRITICAL' => const Color(0xFFFF3B5C),
      'WARNING'  => const Color(0xFFFFB300),
      _          => const Color(0xFF2979FF),
    };

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BottomNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
      ),
    );
  }
}
