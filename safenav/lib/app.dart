import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/map/screens/map_screen.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'member3_alerts/services/alert_service.dart';
import 'shared/screens/driver_score_screen.dart';
import 'shared/screens/profile_screen.dart';
import 'shared/widgets/active_navigation_widget.dart';
import 'shared/widgets/bottom_nav_bar.dart';

class SafeNavApp extends StatefulWidget {
  const SafeNavApp({super.key});

  @override
  State<SafeNavApp> createState() => _SafeNavAppState();
}

class _SafeNavAppState extends State<SafeNavApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppConstants.routeHome,
                  builder: (context, state) => const DashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppConstants.routeMap,
                  builder: (context, state) => const MapScreen(),
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
  }

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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          widget.navigationShell,
          // Nav popup — bottom-right corner, clears the nav bar, hidden on map
          if (widget.navigationShell.currentIndex != 1)
            Positioned(
              right: 16,
              bottom: 92 + bottomInset + 12,
              child: const ActiveNavigationWidget(),
            ),
        ],
      ),
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
