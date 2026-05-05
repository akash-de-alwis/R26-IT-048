import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── LAYER 1: Full-screen background image ───────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/useronboard2.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),


          // ── LAYER 3: Bottom content ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded,
                            size: 18, color: Color(0xFF2979FF)),
                        SizedBox(width: 8),
                        Text(
                          'SafeNav',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Welcome\nback, driver.',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1B2A),
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Sign in to save your trips,\nscores and safety history.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5C6B7A),
                        height: 1.55,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Auth buttons
                    Consumer<AuthService>(
                      builder: (ctx, auth, _) => Column(
                        children: [
                          // Google Sign-In button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      final ok =
                                          await auth.signInWithGoogle();
                                      if (ok && ctx.mounted) {
                                        ctx.go('/home');
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D1B2A),
                                elevation: 0,
                                side: const BorderSide(
                                    color: Color(0xFFDDE3EA), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF2979FF),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color:
                                                    const Color(0xFFE8EDF2)),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'G',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF4285F4),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0D1B2A),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Error message
                          if (auth.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFFF3B5C),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          const SizedBox(height: 14),

                          // Skip link
                          GestureDetector(
                            onTap: () => ctx.go('/home'),
                            child: const Text(
                              'Continue without account',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFADB8C3),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFADB8C3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
