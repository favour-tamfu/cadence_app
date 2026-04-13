import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool startAtAuthGate;

  const OnboardingScreen({
    super.key,
    this.startAtAuthGate = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    // If returning user — jump straight to auth gate (page 4)
    if (widget.startAtAuthGate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(4);
        setState(() => _currentPage = 4);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToSignUp();
    }
  }

  void _skip() => _goToSignUp();

  Future<void> _markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
  }

  void _goToSignUp() {
    // Do NOT mark seen here — mark it after successful signup instead
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SignUpScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: Column(
          children: [
            _buildSkipButton(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                  _buildPage5(),
                ],
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  // ── SKIP BUTTON ─────────────────────────────────────────────────────────────
  Widget _buildSkipButton() {
    if (_currentPage == 0 || _currentPage == _totalPages - 1) {
      return const SizedBox(height: 48);
    }
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _skip,
        child: Text(
          'Skip',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            fontFamily: 'DM Sans',
          ),
        ),
      ),
    );
  }

  // ── BOTTOM SECTION ──────────────────────────────────────────────────────────
  Widget _buildBottomSection() {
    // Page 5 (auth gate) has its own buttons built into the page
    if (_currentPage == _totalPages - 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalPages, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.amberLight
                    : AppColors.muted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.amberLight
                      : AppColors.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const SizedBox(height: 28),

          // Primary button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: Text(
                _primaryButtonLabel(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // "I already have an account" — page 1 only
          if (_currentPage == 0) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goToLogin,
              child: Text(
                'I already have an account',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.cream,
                  fontFamily: 'DM Sans',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _primaryButtonLabel() {
    switch (_currentPage) {
      case 0: return 'Get started';
      case 1: return "That's exactly me →";
      case 2: return "There's more →";
      case 3: return "Let's go →";
      default: return 'Next';
    }
  }


  // Builds one bar of the waveform logo
  Widget _bar(double height, double opacity, {
    bool isAmber = false,
    required int delay,
  }) {
    return Container(
      width: isAmber ? 12 : 10,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isAmber
            ? AppColors.amberLight
            : AppColors.cream.withOpacity(opacity),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  // ── PAGE 1 — Welcome ────────────────────────────────────────────────────────
  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // ── Logo mark (the waveform)
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(10, 0.18, delay: 0),
                _bar(16, 0.35, delay: 1),
                _bar(28, 0.62, delay: 2),
                _bar(40, 1.0, isAmber: true, delay: 3),
                _bar(28, 0.62, delay: 4),
                _bar(16, 0.35, delay: 5),
                _bar(10, 0.18, delay: 6),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Wordmark
          const Text(
            'Cadence',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 48,
              fontWeight: FontWeight.w400,
              color: AppColors.cream,
              letterSpacing: 3,
            ),
          ),

          const SizedBox(height: 12),

          // ── Tagline
          Text(
            'READ WITH PURPOSE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              letterSpacing: 4,
            ),
          ),

        ],
      ),
    );
  }

  // ── PAGE 2 — The Problem ────────────────────────────────────────────────────
  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Book shelf illustration
          Center(child: _buildBookShelf()),
          const SizedBox(height: 28),

          // Stat card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '79%',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 48,
                    fontWeight: FontWeight.w400,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'of books bought are never finished',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontFamily: 'DM Sans',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Sound familiar?',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You buy a book with the best intentions. You read the first chapter. Life happens. Three months later, it\'s still sitting there — spine unbroken, making you feel guilty.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.muted,
              fontFamily: 'DM Sans',
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE 3 — The Pacer ──────────────────────────────────────────────────────
  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // ── Pacer demo card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.amber.withOpacity(0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR PACER GOAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.amber,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '18',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 52,
                        color: AppColors.cream,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'pages',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.cream.withOpacity(0.65),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Read 18 pages today to stay on track',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 0.38,
                    minHeight: 4,
                    backgroundColor: AppColors.cream.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.amber),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('7 pages read', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text('11 to go', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Three chips
          Row(
            children: [
              _pacerChip('Finish date', 'Apr 15'),
              const SizedBox(width: 8),
              _pacerChip('Days remaining', '18'),
              const SizedBox(width: 8),
              _pacerChip('Pages/day', '18'),
            ],
          ),

          const SizedBox(height: 32),

          // ── Headline
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Meet the Pacer.',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 30,
                color: AppColors.cream,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Tell Cadence when you want to finish. It calculates exactly how many pages to read today. Not a vague reminder — an actual number, every day.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.cream.withOpacity(0.65),
              height: 1.75,
              fontWeight: FontWeight.w300,
            ),
          ),

        ],
      ),
    );
  }

  Widget _pacerChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cream.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cream.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                color: AppColors.amberLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ── PAGE 4 — AI Tutor ───────────────────────────────────────────────────────
  Widget _buildPage4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // ── Reader preview with highlighted text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cream.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cream.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Passage with highlight
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.cream.withOpacity(0.65),
                      height: 1.8,
                      fontWeight: FontWeight.w300,
                    ),
                    children: [
                      const TextSpan(text: 'You do not rise to the level of your goals — '),
                      TextSpan(
                        text: 'you fall to the level of your systems.',
                        style: TextStyle(
                          backgroundColor: AppColors.amber.withOpacity(0.18),
                          color: AppColors.amberLight,
                        ),
                      ),
                      const TextSpan(text: ' A goal is a destination. A system is the vehicle that gets you there.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    _aiAction('Summarise'),
                    const SizedBox(width: 6),
                    _aiAction('Explain'),
                    const SizedBox(width: 6),
                    _aiAction('Visualise'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── AI response panel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E52),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cream.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'AI Tutor · Explanation',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Think of your goals as the destination on a map, and your systems as the actual road. You can stare at the destination all day, but without a reliable road to drive on, you won\'t get there.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.cream.withOpacity(0.65),
                    height: 1.75,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Headline with amber word
          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 30,
                  color: AppColors.cream,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  const TextSpan(text: 'Stuck? Just '),
                  TextSpan(
                    text: 'highlight.',
                    style: TextStyle(color: AppColors.amberLight),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Highlight any passage and your AI Tutor breaks it down instantly — summaries, plain-English explanations, or visual illustrations. For students, this changes everything.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.cream.withOpacity(0.65),
              height: 1.75,
              fontWeight: FontWeight.w300,
            ),
          ),

        ],
      ),
    );
  }

  Widget _aiAction(String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.amber.withOpacity(0.2)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.amberLight,
          ),
        ),
      ),
    );
  }
  // ── PAGE 5 — Auth Gate ──────────────────────────────────────────────────────
  Widget _buildPage5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [

          const SizedBox(height: 48),

          // ── Logo mark
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(10, 0.18, delay: 0),
              _bar(16, 0.35, delay: 1),
              _bar(28, 0.62, delay: 2),
              _bar(40, 1.0, isAmber: true, delay: 3),
              _bar(28, 0.62, delay: 4),
              _bar(16, 0.35, delay: 5),
              _bar(10, 0.18, delay: 6),
            ],
          ),

          const SizedBox(height: 24),

          // ── Headline
          const Text(
            'Start reading\nwith purpose.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 32,
              color: AppColors.cream,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Free to get started. No credit card needed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),

          const SizedBox(height: 28),

          // ── Perks
          _perk('Daily page goals tailored to your schedule'),
          const SizedBox(height: 10),
          _perk('Upload your own PDFs — lectures, textbooks, anything'),
          const SizedBox(height: 10),
          _perk('Track streaks, stats, and books finished'),

          const SizedBox(height: 28),

          // ── Primary CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _goToSignUp,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Create free account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),

          const SizedBox(height: 20),

          // ── Divider
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.cream.withOpacity(0.12), thickness: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or continue with', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              Expanded(child: Divider(color: AppColors.cream.withOpacity(0.12), thickness: 0.5)),
            ],
          ),

          const SizedBox(height: 16),

          // ── Google button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.g_mobiledata, size: 22),
              label: const Text('Continue with Google', style: TextStyle(fontSize: 14)),
            ),
          ),

          const SizedBox(height: 10),

          // ── GitHub button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.code, size: 18),
              label: const Text('Continue with GitHub', style: TextStyle(fontSize: 14)),
            ),
          ),

          const SizedBox(height: 16),

          // ── Terms
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6),
              children: [
                const TextSpan(text: 'By signing up you agree to our '),
                TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(color: AppColors.amberLight),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(color: AppColors.amberLight),
                ),
                const TextSpan(text: '. Your data is always private.'),
              ],
            ),
          ),

          const SizedBox(height: 32),

        ],
      ),
    );
  }

  Widget _perk(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: AppColors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.check, size: 14, color: AppColors.amberLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cream.withOpacity(0.65),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  // ── SHARED WIDGETS ──────────────────────────────────────────────────────────

  Widget _buildWaveformIcon() {
    final List<double> heights = [12, 20, 32, 48, 32, 20, 12];
    final List<Color> colors = [
      AppColors.muted.withOpacity(0.3),
      AppColors.muted.withOpacity(0.5),
      AppColors.muted.withOpacity(0.7),
      AppColors.amberLight,
      AppColors.muted.withOpacity(0.7),
      AppColors.muted.withOpacity(0.5),
      AppColors.muted.withOpacity(0.3),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: i == 3 ? 10 : 8,
            height: heights[i],
            decoration: BoxDecoration(
              color: colors[i],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBookShelf() {
    // Simple stylised book spines
    final books = [
      {'h': 100.0, 'color': AppColors.slate},
      {'h': 80.0,  'color': AppColors.slate.withOpacity(0.6)},
      {'h': 120.0, 'color': AppColors.amber},      // highlighted book
      {'h': 90.0,  'color': AppColors.slate.withOpacity(0.6)},
      {'h': 110.0, 'color': AppColors.slate},
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: books.map((b) {
        final isHighlighted = b['color'] == AppColors.amber;
        return Container(
          width: isHighlighted ? 44 : 36,
          height: b['h'] as double,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: b['color'] as Color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: isHighlighted
              ? Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Container(height: 3, color: AppColors.cream.withOpacity(0.6)),
                const SizedBox(height: 6),
                Container(height: 3, color: AppColors.cream.withOpacity(0.4)),
              ],
            ),
          )
              : Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Container(
                    height: 2,
                    color: AppColors.cream.withOpacity(0.2)),
                const SizedBox(height: 5),
                Container(
                    height: 2,
                    color: AppColors.cream.withOpacity(0.15)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.slate,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.muted,
                fontFamily: 'DM Sans',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.amber,
                fontFamily: 'DM Sans',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.cream,
          fontFamily: 'DM Sans',
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.slate,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.cream,
              fontFamily: 'DM Sans',
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

// ── Google G painter ─────────────────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw quadrants
    final segments = [
      {'color': const Color(0xFF4285F4), 'start': -90.0, 'sweep': 90.0},
      {'color': const Color(0xFF34A853), 'start': 0.0,   'sweep': 90.0},
      {'color': const Color(0xFFFBBC05), 'start': 90.0,  'sweep': 90.0},
      {'color': const Color(0xFFEA4335), 'start': 180.0, 'sweep': 90.0},
    ];

    for (final s in segments) {
      paint.color = s['color'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        (s['start'] as double) * 3.14159 / 180,
        (s['sweep'] as double) * 3.14159 / 180,
        true,
        paint,
      );
    }

    // White center cutout
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.55, paint);

    // Blue right bar of G
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - r * 0.2, r * 0.95, r * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}