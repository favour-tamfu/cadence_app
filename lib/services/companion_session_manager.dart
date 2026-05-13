import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../models/book_session.dart';
import '../models/companion.dart';
import 'ai_service.dart';

// ─────────────────────────────────────────────────────────────
//  CompanionSessionManager
//  The single controller the UI talks to.
//  Owns one BookSession at a time (the open book).
// ─────────────────────────────────────────────────────────────
class CompanionSessionManager extends ChangeNotifier {
  CompanionSessionManager({required SessionRepository repository})
      : _repo = repository;

  final SessionRepository _repo;
  final AIService _ai = AIService.instance;

  BookSession? _session;
  BookSession? get session => _session;

  bool _isThinking = false;
  bool get isThinking => _isThinking;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  double _scanProgress = 0.0;
  double get scanProgress => _scanProgress;

  String _streamBuffer = '';
  String get streamBuffer => _streamBuffer;
  bool get isStreaming => _streamBuffer.isNotEmpty && _isThinking;

  // ── Session lifecycle ─────────────────────────────────────

  Future<void> openSession({
    required String bookId,
    required String title,
    String author = '',
    String genre = '',
    String fullBookText = '',
    CompanionConfig? overrideConfig,
  }) async {
    var session = _repo.loadSession(bookId);
    if (session == null) {
      // 1. new book- create from scratch
      final config = overrideConfig ?? _repo.loadGlobalConfig();
      session = BookSession(
        bookId: bookId,
        bookTitle: title,
        bookAuthor: author,
        genre: genre,
        companionConfig: config,
        createdAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );
      await _repo.saveSession(session);
    } else {
      // 2. Existing book - self-heal corrupted data from old debugging sessions!
      session = session.copyWith(
          lastOpenedAt: DateTime.now(),
    // If the saved session has a blank title, overwrite it with the real one
    bookTitle: session.bookTitle.isEmpty ? title : session.bookTitle,
    // (Optional) Do the same for author if you ever pass it
    bookAuthor: session.bookAuthor.isEmpty ? author : session.bookAuthor,
    );
      await _repo.saveSession(session);
    }

    _session = session;
    notifyListeners();

// 3. Trigger the background scan if it hasn't successfully finished yet
    if (fullBookText.isNotEmpty &&
        (session.scanState == ScanState.pending ||
            session.scanState == ScanState.failed)) {
      _startBackgroundScan(session, fullBookText);
    }
  }

  Future<void> applyFirstOpenConfig({
    required CompanionConfig config,
    required String readerGoal,
  }) async {
    if (_session == null) return;
    final updated = _session!.copyWith(
      companionConfig: config,
      readerGoal: readerGoal,
    );
    _session = await _repo.saveSession(updated).then((_) => updated);
    notifyListeners();
  }

  Future<void> updateCompanionConfig(CompanionConfig config) async {
    if (_session == null) return;
    final updated = _session!.copyWith(companionConfig: config);
    _session = updated;
    await _repo.saveSession(updated);
    notifyListeners();
  }

  void closeSession() {
    _session = null;
    _streamBuffer = '';
    _isThinking = false;
    notifyListeners();
  }

  // ── Messaging ─────────────────────────────────────────────

  Future<void> sendMessage(
    String text, {
    String? highlightedPassage,
  }) async {
    if (_session == null || _isThinking) return;

    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
      highlightedPassage: highlightedPassage,
    );
    _session = await _repo.appendMessage(_session!, userMsg);
    _isThinking = true;
    notifyListeners();

    try {
      final response = await _ai.chat(
        session: _session!,
        userMessage: text,
        highlightedPassage: highlightedPassage,
      );

      final isOutOfBook = response.startsWith('This goes beyond the book');
      final assistantMsg = ChatMessage(
        role: MessageRole.assistant,
        content: response,
        timestamp: DateTime.now(),
        isOutOfBook: isOutOfBook,
        highlightedPassage: highlightedPassage,
      );
      _session = await _repo.appendMessage(_session!, assistantMsg);
    } finally {
      _isThinking = false;
      notifyListeners();
    }
  }

  Future<void> sendMessageStreaming(
    String text, {
    String? highlightedPassage,
  }) async {
    if (_session == null || _isThinking) return;

    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
      highlightedPassage: highlightedPassage,
    );
    _session = await _repo.appendMessage(_session!, userMsg);
    _isThinking = true;
    _streamBuffer = '';
    notifyListeners();

    try {
      final stream = _ai.chatStream(
        session: _session!,
        userMessage: text,
        highlightedPassage: highlightedPassage,
      );

      await for (final chunk in stream) {
        _streamBuffer += chunk;
        notifyListeners();
      }

      final fullResponse = _streamBuffer.trim();
      _streamBuffer = '';

      final isOutOfBook = fullResponse.startsWith('This goes beyond the book');
      final assistantMsg = ChatMessage(
        role: MessageRole.assistant,
        content: fullResponse,
        timestamp: DateTime.now(),
        isOutOfBook: isOutOfBook,
        highlightedPassage: highlightedPassage,
      );
      _session = await _repo.appendMessage(_session!, assistantMsg);
    } finally {
      _isThinking = false;
      _streamBuffer = '';
      notifyListeners();
    }
  }

  // ── Structured actions ────────────────────────────────────

  Future<String> summarisePassage(String passage) async {
    if (_session == null) return '';
    return _ai.summarise(passage, _session!);
  }

  Future<String> explainPassage(String passage) async {
    if (_session == null) return '';
    return _ai.explain(passage, _session!);
  }

  Future<List<String>> extractKeyConcepts(String passage) async {
    return _ai.keyConcepts(passage);
  }

  Future<String> askAboutPassage(String passage, String question) async {
    if (_session == null) return '';
    return _ai.ask(passage, question, _session!);
  }

  Future<String> getConceptMapJson(String passage) async {
    return _ai.conceptMapJson(passage);
  }

  Future<String?> triggerProactiveNudge([String currentPassage = '']) async {
    if (_session == null) return null;
    if (!_session!.companionConfig.proactiveNudges) return null;
    return _ai.proactiveNudge(_session!, currentPassage);
  }

  // ── Progress ──────────────────────────────────────────────

  Future<void> updateProgress(double progress) async {
    if (_session == null) return;
    _session = await _repo.updateProgress(_session!, progress);
    notifyListeners();
  }

  // ── Background scan ───────────────────────────────────────

  void _startBackgroundScan(BookSession session, String fullText) async {
    if (_isScanning) return;
    _isScanning = true;
    _scanProgress = 0;

    final scanning = session.copyWith(scanState: ScanState.scanning);
    _session = scanning;
    await _repo.saveSession(scanning);
    notifyListeners();

    try {
      final result = await _ai.scanBook(
        fullText: fullText,
        bookTitle: session.bookTitle,
        author: session.bookAuthor,
        onProgress: (p) {
          _scanProgress = p;
          notifyListeners();
        },
      );

      final updated = await _repo.updateScanResult(
        session: _session!,
        chunks: result.chunks,
        bookMapSummary: result.bookMap,
      );
      _session = updated;
    } catch (_) {
      final failed = _session!.copyWith(scanState: ScanState.failed);
      _session = failed;
      await _repo.saveSession(failed);
    } finally {
      _isScanning = false;
      _scanProgress = 0;
      notifyListeners();
    }
  }

  // ── All sessions (for library view) ──────────────────────

  List<BookSession> get allSessions => _repo.loadAllSessions();

  Future<void> deleteSession(String bookId) async {
    await _repo.deleteSession(bookId);
    if (_session?.bookId == bookId) closeSession();
    notifyListeners();
  }
}
