import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Waveform bars — repeating bounce
  late AnimationController _barsController;
  late List<Animation<double>> _barAnims;

  // Title + subtitle — fade & slide in
  late AnimationController _wordController;
  late Animation<double> _wordFade;
  late Animation<Offset> _wordSlide;

  // Tagline — delayed fade in
  late AnimationController _taglineController;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;

  // Bottom progress bar — fills over the full 8 seconds
  late AnimationController _progressController;

  // ── Total splash display time before navigating (ms) — adjust to shorten/lengthen the splash
  static const _totalMs = 8000;

  final List<double> _maxHeights = [20, 36, 56, 80, 56, 36, 20];
  final List<Color> _barColors = [
    Color(0x30F7F2EA), Color(0x59F7F2EA), Color(0x9EF7F2EA),
    AppColors.amberLight,
    Color(0x9EF7F2EA), Color(0x59F7F2EA), Color(0x30F7F2EA),
  ];

  @override
  void initState() {
    super.initState();

    // ── Waveform — repeating
    // Duration = one full bounce cycle (up → down). Increase for a slower pulse.
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000), // waveform pulse cycle
    )..repeat(reverse: true);

    _barAnims = List.generate(7, (i) {
      final delay = i * 0.05;
      return Tween<double>(begin: 8, end: _maxHeights[i]).animate(
        CurvedAnimation(
          parent: _barsController,
          curve: Interval(delay, (delay + 0.6).clamp(0, 1),
              curve: Curves.easeInOut),
        ),
      );
    });

    // ── Title + subtitle — fade + slide at 300 ms
    // Duration = how long the fade-in animation lasts
    _wordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // title fade-in duration
    );
    _wordFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _wordController, curve: Curves.easeOut),
    );
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, 0.3), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _wordController, curve: Curves.easeOut,
    ));

    // ── Tagline — fade + slide at 1 500 ms
    // Duration = how long the tagline fade-in animation lasts
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // tagline fade-in duration
    );
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.4), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _taglineController, curve: Curves.easeOut,
    ));

    // ── Progress bar — fills over the full 8 s
    // Tied to _totalMs so the bar always fills exactly as the splash ends
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs), // matches total splash time
    )..forward();

    // Kick off sequenced animations
    Future.delayed(const Duration(milliseconds: 300), () { // delay before title appears
      if (mounted) _wordController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1500), () { // delay before tagline appears
      if (mounted) _taglineController.forward();
    });

    // Navigate after splash ends — controlled by _totalMs above
    Future.delayed(const Duration(milliseconds: _totalMs), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    final destination = seenOnboarding
        ? const HomeScreen()
        : const OnboardingScreen();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500), // fade-out to next screen
      ),
    );
  }

  @override
  void dispose() {
    _barsController.dispose();
    _wordController.dispose();
    _taglineController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: [

          // ── Subtle radial glow behind the logo
          Positioned.fill(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.amber.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Centre: waveform + title + tagline
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Waveform bars
                AnimatedBuilder(
                  animation: _barsController,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: i == 3 ? 12 : 10,
                          height: _barAnims[i].value,
                          decoration: BoxDecoration(
                            color: _barColors[i],
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 28),

                // "Cadence" title
                FadeTransition(
                  opacity: _wordFade,
                  child: SlideTransition(
                    position: _wordSlide,
                    child: const Text(
                      'Cadence',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 48,
                        fontWeight: FontWeight.w400,
                        color: AppColors.cream,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // "READ WITH PURPOSE" subtitle
                FadeTransition(
                  opacity: _wordFade,
                  child: Text(
                    'READ WITH PURPOSE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                      letterSpacing: 3.5,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Text(
                      'Build your reading habit,\none page at a time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.cream.withOpacity(0.5),
                        fontFamily: 'PlayfairDisplay',
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom: amber progress bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (_, __) => LinearProgressIndicator(
                value: _progressController.value,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                  AppColors.amber.withOpacity(0.6),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
