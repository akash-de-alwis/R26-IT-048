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
      image: 'assets/userinteract 1.png',
      title: 'See live risk\nsummaries before\nyou set off',
      buttonText: 'Next',
      isLastPage: false,
    ),
    _PageData(
      image: 'assets/userinteract 2.png',
      title: 'Track every trip\nand drive with\nconfidence',
      buttonText: 'Get Started',
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
