import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_session.dart';
import '../models/companion.dart';

// ─────────────────────────────────────────────────────────────
//  SessionRepository
//  Persists all BookSessions locally via shared_preferences.
//  One key per book: 'cadence_session_<bookId>'
//  Index key: 'cadence_session_index' → list of bookIds
// ─────────────────────────────────────────────────────────────
class SessionRepository {
  static const _indexKey = 'cadence_session_index';
  static const _prefix = 'cadence_session_';
  static const _globalConfigKey = 'cadence_global_companion_config';

  static SharedPreferences? _cachedPrefs;

  final SharedPreferences _prefs;

  // No-arg constructor — call initialize() in main() before using this
  SessionRepository()
      : _prefs = _cachedPrefs ??
            (throw StateError(
              'Call SessionRepository.initialize() before creating SessionRepository()',
            ));

  SessionRepository._internal(SharedPreferences prefs) : _prefs = prefs;

  /// Call once in main() before runApp to enable the no-arg constructor.
  static Future<void> initialize() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
  }

  static Future<SessionRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    return SessionRepository._internal(prefs);
  }

  // ── Global companion config ───────────────────────────────

  Future<void> saveGlobalConfig(CompanionConfig config) async {
    await _prefs.setString(_globalConfigKey, jsonEncode(config.toJson()));
  }

  CompanionConfig loadGlobalConfig() {
    final raw = _prefs.getString(_globalConfigKey);
    if (raw == null) return CompanionConfig.defaultFor(CompanionType.echo);
    try {
      return CompanionConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return CompanionConfig.defaultFor(CompanionType.echo);
    }
  }

  // ── BookSession CRUD ──────────────────────────────────────

  Future<void> saveSession(BookSession session) async {
    final key = '$_prefix${session.bookId}';
    await _prefs.setString(key, session.toJsonString());
    final index = _loadIndex();
    if (!index.contains(session.bookId)) {
      index.add(session.bookId);
      await _prefs.setString(_indexKey, jsonEncode(index));
    }
  }

  BookSession? loadSession(String bookId) {
    final raw = _prefs.getString('$_prefix$bookId');
    if (raw == null) return null;
    try {
      return BookSession.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  List<BookSession> loadAllSessions() {
    return _loadIndex()
        .map(loadSession)
        .whereType<BookSession>()
        .toList()
      ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
  }

  Future<void> deleteSession(String bookId) async {
    await _prefs.remove('$_prefix$bookId');
    final index = _loadIndex()..remove(bookId);
    await _prefs.setString(_indexKey, jsonEncode(index));
  }

  List<String> _loadIndex() {
    final raw = _prefs.getString(_indexKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return [];
    }
  }

  // ── Convenience helpers ───────────────────────────────────

  Future<BookSession> appendMessage(
    BookSession session,
    ChatMessage message,
  ) async {
    final updated = session.copyWith(
      messages: [...session.messages, message],
      lastOpenedAt: DateTime.now(),
    );
    await saveSession(updated);
    return updated;
  }

  Future<BookSession> updateScanResult({
    required BookSession session,
    required List<BookChunk> chunks,
    required String bookMapSummary,
  }) async {
    final updated = session.copyWith(
      scanState: ScanState.complete,
      bookChunks: chunks,
      bookMapSummary: bookMapSummary,
    );
    await saveSession(updated);
    return updated;
  }

  Future<BookSession> updateProgress(
    BookSession session,
    double progress,
  ) async {
    final updated = session.copyWith(
      progressPercent: progress,
      lastOpenedAt: DateTime.now(),
    );
    await saveSession(updated);
    return updated;
  }
}
