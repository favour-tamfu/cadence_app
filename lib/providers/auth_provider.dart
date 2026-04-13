// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

// Single instance of AuthService
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Watches auth state changes — rebuilds any widget that depends on it
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Simple bool — is there a logged in user right now?
final isSignedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((state) =>
  state.session != null).valueOrNull ?? false;
});