import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import '../services/companion_session_manager.dart';
import '../services/companion_settings_service.dart';

// ─────────────────────────────────────────────────────────────
//  Companion providers
//  companionRepositoryProvider must be overridden in main.dart
//  after SessionRepository.create() resolves.
//
//  In main.dart:
//    final repo = await SessionRepository.create();
//    runApp(ProviderScope(
//      overrides: [companionRepositoryProvider.overrideWithValue(repo)],
//      child: const CadenceApp(),
//    ));
// ─────────────────────────────────────────────────────────────

final companionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw UnimplementedError('Override companionRepositoryProvider in main.dart'),
);

final companionSessionManagerProvider =
    ChangeNotifierProvider<CompanionSessionManager>(
  (ref) => CompanionSessionManager(
    repository: ref.watch(companionRepositoryProvider),
  ),
);

final companionSettingsServiceProvider =
    ChangeNotifierProvider<CompanionSettingsService>(
  (ref) => CompanionSettingsService(
    repository: ref.watch(companionRepositoryProvider),
  ),
);
