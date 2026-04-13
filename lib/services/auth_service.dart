// lib/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  // ── Stream: emits whenever auth state changes ──────────────────────────────
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Current session / user ─────────────────────────────────────────────────
  Session? get currentSession => _client.auth.currentSession;
  User?    get currentUser    => _client.auth.currentUser;
  bool     get isSignedIn     => currentUser != null;

  // ── Email / Password sign up ───────────────────────────────────────────────
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    // Create profile row immediately after sign up
    if (response.user != null) {
      await _createProfile(
        userId: response.user!.id,
        fullName: fullName,
        email: email,
      );
    }

    return response;
  }

  // ── Email / Password sign in ───────────────────────────────────────────────
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Google OAuth ───────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.cadence.app://login-callback',
    );
  }

  // ── GitHub OAuth ───────────────────────────────────────────────────────────
  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: 'io.cadence.app://login-callback',
    );
  }

  // ── Password reset ─────────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.cadence.app://reset-callback',
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Private: create profile row after sign up ──────────────────────────────
  Future<void> _createProfile({
    required String userId,
    required String fullName,
    required String email,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'username': email.split('@').first, // default username from email
      'is_premium': false,
      'streak': 0,
    });
  }
}