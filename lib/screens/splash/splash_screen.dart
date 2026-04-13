import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  late AnimationController _barsController;
  late AnimationController _wordController;
  late List<Animation<double>> _barAnims;
  late Animation<double> _wordFade;
  late Animation<Offset> _wordSlide;

  final List<double> _maxHeights = [20, 36, 56, 80, 56, 36, 20];
  final List<Color> _barColors = [
    Color(0x30F7F2EA), Color(0x59F7F2EA), Color(0x9EF7F2EA),
    AppColors.amberLight,
    Color(0x9EF7F2EA), Color(0x59F7F2EA), Color(0x30F7F2EA),
  ];

  @override
  void initState() {
    super.initState();

    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _wordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

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

    _wordFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _wordController, curve: Curves.easeOut),
    );
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, 0.3), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _wordController, curve: Curves.easeOut,
    ));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _wordController.forward();
    });

    Future.delayed(const Duration(milliseconds: 2800), _navigate);
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
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _barsController.dispose();
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _barsController,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: Duration.zero,
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

            FadeTransition(
              opacity: _wordFade,
              child: SlideTransition(
                position: _wordSlide,
                child: const Text(
                  'Cadence',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 42,
                    fontWeight: FontWeight.w400,
                    color: AppColors.cream,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

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
          ],
        ),
      ),
    );
  }
}