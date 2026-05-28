import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  int _dotIndex = 0;
  int _tick = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      _tick++;
      setState(() => _dotIndex = _tick % 3);
      if (_tick >= 5) {
        _dotTimer?.cancel();
        _navigate();
      }
    });
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user != null) {
      context.go(AppConstants.routeHome);
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // ── LAYER 1: Full-screen background image ──────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/splashcreen.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),

            // ── LAYER 3: Center logo ────────────────────────────────────
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded,
                          size: 32, color: Color(0xFF2979FF)),
                      SizedBox(width: 10),
                      Text(
                        'SafeNav',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1B2A),
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Drive Safe. Arrive Safe.',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFFADB8C3),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── LAYER 4: Animated loading dots ──────────────────────────
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final active = i == _dotIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 20.0 : 6.0,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF2979FF)
                            : const Color(0xFFDDE3EA),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
