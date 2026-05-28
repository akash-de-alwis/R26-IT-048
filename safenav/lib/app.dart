import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/billing/screens/billing_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/map/screens/map_screen.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
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
        GoRoute(
          path: '/billing',
          builder: (context, state) => const BillingScreen(),
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
  Offset? _navOffset; // null = use default bottom-right position

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;

    // Card dimensions (width 168, height ≈ 175 including close-button overhang)
    const cardW = 184.0; // 168 + 16 right margin
    const cardH = 180.0;

    // Initialise to bottom-right on first build
    _navOffset ??= Offset(
      mq.size.width - cardW,
      mq.size.height - 92 - bottomInset - 12 - cardH,
    );

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          widget.navigationShell,
          // Nav popup — draggable, hidden on map tab
          if (widget.navigationShell.currentIndex != 1)
            Positioned(
              left: _navOffset!.dx,
              top: _navOffset!.dy,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _navOffset = Offset(
                      (_navOffset!.dx + d.delta.dx)
                          .clamp(0.0, mq.size.width - cardW),
                      (_navOffset!.dy + d.delta.dy)
                          .clamp(0.0, mq.size.height - cardH),
                    );
                  });
                },
                child: const ActiveNavigationWidget(),
              ),
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
