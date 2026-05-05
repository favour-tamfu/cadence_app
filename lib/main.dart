import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'services/companion_session_manager.dart';
import 'services/session_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await SessionRepository.initialize();

  runApp(
    // Riverpod wraps everything
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CompanionSessionManager(
              repository: SessionRepository(),
            ),
          ),
        ],
        child: const CadenceApp(),
      ),
    ),
  );
}

class CadenceApp extends StatelessWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}