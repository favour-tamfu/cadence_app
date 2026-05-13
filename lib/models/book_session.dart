import 'dart:convert';
import 'companion.dart';

// ─────────────────────────────────────────────────────────────
//  Chat message
// ─────────────────────────────────────────────────────────────
enum MessageRole { user, assistant, system }

class ChatMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isOutOfBook;
  final String? highlightedPassage;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isOutOfBook = false,
    this.highlightedPassage,
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isOutOfBook': isOutOfBook,
        'highlightedPassage': highlightedPassage,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: MessageRole.values.byName(json['role'] as String),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isOutOfBook: json['isOutOfBook'] as bool? ?? false,
        highlightedPassage: json['highlightedPassage'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────
//  Book chunk — produced by background scanner
// ─────────────────────────────────────────────────────────────
class BookChunk {
  final int index;
  final String rawText;
  final String summary;
  final int startOffset;
  final int endOffset;

  const BookChunk({
    required this.index,
    required this.rawText,
    required this.summary,
    required this.startOffset,
    required this.endOffset,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'rawText': rawText,
        'summary': summary,
        'startOffset': startOffset,
        'endOffset': endOffset,
      };

  factory BookChunk.fromJson(Map<String, dynamic> json) => BookChunk(
        index: json['index'] as int,
        rawText: json['rawText'] as String,
        summary: json['summary'] as String,
        startOffset: json['startOffset'] as int,
        endOffset: json['endOffset'] as int,
      );
}

// ─────────────────────────────────────────────────────────────
//  Scan state
// ─────────────────────────────────────────────────────────────
enum ScanState { pending, scanning, complete, failed }

// ─────────────────────────────────────────────────────────────
//  BookSession — one per book, persisted across app sessions
// ─────────────────────────────────────────────────────────────
class BookSession {
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String genre;

  final CompanionConfig companionConfig;

  final String readerGoal;
  final double progressPercent;

  final List<ChatMessage> messages;

  final ScanState scanState;
  final List<BookChunk> bookChunks;
  final String? bookMapSummary;

  final DateTime createdAt;
  final DateTime lastOpenedAt;

  const BookSession({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.genre,
    required this.companionConfig,
    this.readerGoal = '',
    this.progressPercent = 0.0,
    this.messages = const [],
    this.scanState = ScanState.pending,
    this.bookChunks = const [],
    this.bookMapSummary,
    required this.createdAt,
    required this.lastOpenedAt,
  });

  BookSession copyWith({
    String? bookId,
    String? bookTitle,
    String? bookAuthor,
    String? genre,
    CompanionConfig? companionConfig,
    String? readerGoal,
    double? progressPercent,
    List<ChatMessage>? messages,
    ScanState? scanState,
    List<BookChunk>? bookChunks,
    String? bookMapSummary,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
  }) {
    return BookSession(
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      genre: genre ?? this.genre,
      companionConfig: companionConfig ?? this.companionConfig,
      readerGoal: readerGoal ?? this.readerGoal,
      progressPercent: progressPercent ?? this.progressPercent,
      messages: messages ?? this.messages,
      scanState: scanState ?? this.scanState,
      bookChunks: bookChunks ?? this.bookChunks,
      bookMapSummary: bookMapSummary ?? this.bookMapSummary,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor,
        'genre': genre,
        'companionConfig': companionConfig.toJson(),
        'readerGoal': readerGoal,
        'progressPercent': progressPercent,
        'messages': messages.map((m) => m.toJson()).toList(),
        'scanState': scanState.name,
        'bookChunks': bookChunks.map((c) => c.toJson()).toList(),
        'bookMapSummary': bookMapSummary,
        'createdAt': createdAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
      };

  factory BookSession.fromJson(Map<String, dynamic> json) => BookSession(
        bookId: json['bookId'] as String,
        bookTitle: json['bookTitle'] as String,
        bookAuthor: json['bookAuthor'] as String,
        genre: json['genre'] as String? ?? '',
        companionConfig: CompanionConfig.fromJson(
          json['companionConfig'] as Map<String, dynamic>,
        ),
        readerGoal: json['readerGoal'] as String? ?? '',
        progressPercent:
            (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        scanState: ScanState.values.byName(
          json['scanState'] as String? ?? 'pending',
        ),
        bookChunks: (json['bookChunks'] as List<dynamic>? ?? [])
            .map((c) => BookChunk.fromJson(c as Map<String, dynamic>))
            .toList(),
        bookMapSummary: json['bookMapSummary'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory BookSession.fromJsonString(String raw) =>
      BookSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  List<ChatMessage> recentHistory({int limit = 20}) {
    final nonSystem =
        messages.where((m) => m.role != MessageRole.system).toList();
    if (nonSystem.length <= limit) return nonSystem;
    return nonSystem.sublist(nonSystem.length - limit);
  }

  bool get hasBookContext =>
      scanState == ScanState.complete && bookMapSummary != null;

  bool get isNew => messages.isEmpty;
}
