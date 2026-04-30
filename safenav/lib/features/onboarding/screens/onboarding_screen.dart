import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      image: 'assets/useronboard1.png',
      title: 'Know the risk\nbefore you take\nthe road',
      buttonText: 'Next',
      isLastPage: false,
    ),
    _PageData(
      image: 'assets/useronboard2.png',
      title: 'Your safety,\nguided by AI\nevery journey',
      buttonText: 'Take Me In',
      isLastPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    context.go('/login');
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── LAYER 1: Full-screen background image ──────────────────────
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Image.asset(
                page.image,
                key: ValueKey(_currentPage),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // ── PageView (invisible — drives page state) ───────────────────
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) => const SizedBox.expand(),
            ),
          ),

          // ── LAYER 2: White gradient overlay ────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.58, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),

          // ── LAYER 3: Bottom content ─────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page dots
                    Row(
                      children: List.generate(_pages.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 28.0 : 8.0,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF2979FF)
                                : const Color(0xFFDDE3EA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      page.title,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2979FF),
                        height: 1.20,
                        letterSpacing: -0.5,
                        fontFamily: GoogleFonts.inter().fontFamily,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed:
                            page.isLastPage ? _finish : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2979FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          page.buttonText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                    // Skip link — page 1 only
                    if (!page.isLastPage)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Center(
                          child: GestureDetector(
                            onTap: _finish,
                            child: const Text(
                              'Skip for now',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFADB8C3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── LAYER 4: Top logo badge ─────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 16, color: Color(0xFF2979FF)),
                          SizedBox(width: 6),
                          Text(
                            'SafeNav',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D1B2A),
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

class _PageData {
  final String image;
  final String title;
  final String buttonText;
  final bool isLastPage;

  const _PageData({
    required this.image,
    required this.title,
    required this.buttonText,
    required this.isLastPage,
  });
}
