import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/book_session.dart';
import '../models/companion.dart';
import 'prompt_builder.dart';

enum SubscriptionTier {
  free,
  basic,
  premium;

  bool get canUseImageGen => this != SubscriptionTier.free;
}

class _Models {
  // Put back to your actual dashboard models!
  static const free    = 'gemini-2.5-flash-lite';
  static const basic   = 'gemini-2.5-flash';
  static const premium = 'gemini-2.5-pro';

  static const scan    = 'gemini-2.5-flash-lite';
  static const imageGen = 'gemini-2.5-flash-image';
  static const fallback = 'gemini-2.5-flash-lite';
}

const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

class AIService {
  static AIService? _instance;
  static AIService get instance => _instance ??= AIService._();
  AIService._();

  final http.Client _http = http.Client();

  SubscriptionTier tier = SubscriptionTier.basic;

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  String get _textModel => switch (tier) {
    SubscriptionTier.free    => _Models.free,
    SubscriptionTier.basic   => _Models.basic,
    SubscriptionTier.premium => _Models.premium,
  };

  // ── Chat (main companion conversation) ────────────────────

  Future<String> chat({
    required BookSession session,
    required String userMessage,
    String? highlightedPassage,
  }) async {
    final systemPrompt = PromptBuilder.buildSystemPrompt(session);
    final contents = [
      ..._historyToContents(session.recentHistory(limit: 20)),
      _userPart(highlightedPassage != null
          ? 'Regarding this passage:\n"$highlightedPassage"\n\n$userMessage'
          : userMessage),
    ];

    try {
      return await _generate(
        model: _textModel,
        contents: contents,
        systemInstruction: systemPrompt,
        type: session.companionConfig.type,
      );
    } catch (e) {
      // CHANGED: Return exact error to UI
      return 'EXACT ERROR: $e';
    }
  }

  // ── Streaming chat ─────────────────────────────────────────

  Stream<String> chatStream({
    required BookSession session,
    required String userMessage,
    String? highlightedPassage,
  }) async* {
    final systemPrompt = PromptBuilder.buildSystemPrompt(session);
    final contents = [
      ..._historyToContents(session.recentHistory(limit: 20)),
      _userPart(highlightedPassage != null
          ? 'Regarding this passage:\n"$highlightedPassage"\n\n$userMessage'
          : userMessage),
    ];

    final bodyMap = <String, dynamic>{
      'system_instruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': {
        'temperature': 0.75,
        'maxOutputTokens': 1024,
        'topP': 0.95,
      },
    };

    final uri = Uri.parse(
      '$_baseUrl/$_textModel:streamGenerateContent?alt=sse&key=$_apiKey',
    );

    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(bodyMap);

      final streamedResponse = await _http.send(request);

      // 🚨 AGGRESSIVE DEBUGGING 🚨
      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();

        // This prints in RED in your IDE console
        debugPrint('====================================');
        debugPrint('🚨 GEMINI API ERROR: HTTP ${streamedResponse.statusCode}');
        debugPrint('🚨 RESPONSE BODY: $errorBody');
        debugPrint('====================================');

        // Force the UI to show this string so you know to look at the console
        yield 'API ERROR ${streamedResponse.statusCode}. Check your Flutter Console for the exact reason!';
        return;
      }

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6).trim();
        if (jsonStr == '[DONE]' || jsonStr.isEmpty) continue;
        try {
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          final text = _extractText(parsed);
          if (text != null && text.isNotEmpty) yield text;
        } catch (_) {
          // Skip
        }
      }
    } catch (e, stack) {
      debugPrint('====================================');
      debugPrint('🚨 EXCEPTION CAUGHT: $e');
      debugPrint('====================================');
      yield 'CRITICAL ERROR: Check your Flutter console!';
    }
  }

  // ── Structured actions (stateless) ───────────────────────

  Future<String> summarise(String passage, BookSession session) =>
      _generateStateless(PromptBuilder.summarise(passage, session.companionConfig), session.companionConfig.type);

  Future<String> explain(String passage, BookSession session) =>
      _generateStateless(PromptBuilder.explain(passage, session.companionConfig), session.companionConfig.type);

  Future<List<String>> keyConcepts(String passage) async {
    final result = await _generateStateless(PromptBuilder.keyConcepts(passage), CompanionType.sage);
    return result.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).take(5).toList();
  }

  Future<String> ask(String passage, String question, BookSession session) =>
      _generateStateless(PromptBuilder.ask(passage, question, session.companionConfig, session.bookMapSummary), session.companionConfig.type);

  Future<String> conceptMapJson(String passage) =>
      _generateStateless(PromptBuilder.conceptMap(passage), CompanionType.sage);

  Future<String> proactiveNudge(BookSession session, String passage) =>
      _generateStateless(PromptBuilder.proactiveNudge(passage, session.bookTitle, session.progressPercent, session.companionConfig.type), session.companionConfig.type);

  // ── Image generation ───────────────────────────────

  Future<Uint8List?> generateImage({
    required String description,
    required BookSession session,
  }) async {
    if (!tier.canUseImageGen) return null;
    if (_apiKey.isEmpty) return null;

    final prompt = 'Create a clean, atmospheric illustration for a reading app. Style: minimal, editorial, book-cover quality. No text in the image. Subject: $description. Book: "${session.bookTitle}" by ${session.bookAuthor}.';

    final body = jsonEncode({
      'contents': [{'parts': [{'text': prompt}]}],
      'generationConfig': {'responseModalities': ['TEXT', 'IMAGE']},
    });

    final uri = Uri.parse('$_baseUrl/${_Models.imageGen}:generateContent?key=$_apiKey');

    try {
      final response = await _http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);

      if (response.statusCode != 200) {
        // CHANGED: Print exact image gen error to console
        debugPrint('IMAGE GEN EXACT ERROR: HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
      // ... (rest of image parsing logic remains the same)
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final parts = ((candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>)['parts'] as List<dynamic>?;
      if (parts == null) return null;

      for (final part in parts) {
        final inlineData = (part as Map<String, dynamic>)['inlineData'] as Map<String, dynamic>?;
        if (inlineData != null) {
          final data = inlineData['data'] as String?;
          if (data != null) return base64Decode(data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('IMAGE GEN EXCEPTION: $e');
      return null;
    }
  }

  // ── Background book scanner ───────────────────────────────

  Future<({List<BookChunk> chunks, String bookMap})> scanBook({
    required String fullText,
    required String bookTitle,
    required String author,
    void Function(double)? onProgress,
  }) async {
    const chunkSize = 3000;
    final rawChunks = _splitIntoChunks(fullText, chunkSize);
    final summarised = <BookChunk>[];

    for (var i = 0; i < rawChunks.length; i++) {
      final raw = rawChunks[i];
      final summary = await _generateStateless(
        'You are a silent book indexer for "$bookTitle".\nSummarise this passage...\nPassage:\n"$raw"',
        CompanionType.sage,
        modelOverride: _Models.scan,
      );
      summarised.add(BookChunk(index: i, rawText: raw, summary: summary, startOffset: i * chunkSize, endOffset: (i * chunkSize) + raw.length));
      onProgress?.call((i + 1) / rawChunks.length);
    }

    final allSummaries = summarised.map((c) => 'Section ${c.index + 1}: ${c.summary}').join('\n');
    final bookMap = await _generateStateless(
      'You are a book analyst...\nSection summaries:\n$allSummaries',
      CompanionType.sage,
      maxTokens: 600,
    );

    return (chunks: summarised, bookMap: bookMap);
  }

  // ── Core REST generation ──────────────────────────────────

  Future<String> _generateStateless(
      String prompt,
      CompanionType type, {
        int maxTokens = 1024,
        String? modelOverride,
      }) async {
    final contents = [_userPart(prompt)];
    final model = modelOverride ?? _textModel;

    try {
      return await _generate(
        model: model,
        contents: contents,
        maxTokens: maxTokens,
        type: type,
      );
    } catch (e) {
      // CHANGED: Return exact error string
      return 'STATELESS EXACT ERROR: $e';
    }
  }

  Future<String> _generate({
    required String model,
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
    int maxTokens = 1024,
    required CompanionType type,
  }) async {
    if (_apiKey.isEmpty) return 'ERROR: API Key is missing from .env';

    final bodyMap = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.75,
        'maxOutputTokens': maxTokens,
        'topP': 0.95,
      },
    };

    if (systemInstruction != null) {
      bodyMap['system_instruction'] = {'parts': [{'text': systemInstruction}]};
    }

    final uri = Uri.parse('$_baseUrl/$model:generateContent?key=$_apiKey');

    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );

    if (response.statusCode != 200) {
      // 🚨 NEW AUTO-DEBUGGER 🚨
      // If we get a 404, query Google to find out exactly what models your key has access to!
      if (response.statusCode == 404) {
        try {
          final listUri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey');
          final listRes = await _http.get(listUri);
          final json = jsonDecode(listRes.body);

          // Get all available models and clean up the names
          final availableModels = (json['models'] as List)
              .map((m) => m['name'].toString().replaceAll('models/', ''))
              .where((name) => name.contains('gemini'))
              .join('\n- ');

          throw Exception('HTTP 404: Google rejected "$model".\n\nTHESE ARE THE EXACT MODELS YOUR KEY ALLOWS:\n- $availableModels');
        } catch (_) {
          // If fetching the list fails, just fall through to standard error
        }
      }

      // Standard error for everything else (Quota, 500, etc)
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(json);
    return text?.trim() ?? 'ERROR: Response parsed successfully but no text was found in payload.';
  }

  // ── Helpers ───────────────────────────────────────────────

  Map<String, dynamic> _userPart(String text) => {
    'role': 'user',
    'parts': [{'text': text}],
  };

  List<Map<String, dynamic>> _historyToContents(List<ChatMessage> messages) =>
      messages.where((m) => m.role != MessageRole.system).map((m) => {
        'role': m.role == MessageRole.user ? 'user' : 'model',
        'parts': [{'text': m.content}],
      }).toList();

  String? _extractText(Map<String, dynamic> json) {
    try {
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      return parts.whereType<Map<String, dynamic>>().where((p) => p.containsKey('text')).map((p) => p['text'] as String).join('');
    } catch (_) {
      return null;
    }
  }

  List<String> _splitIntoChunks(String text, int size) {
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = start + size;
      if (end < text.length) {
        final breakPoint = text.lastIndexOf(RegExp(r'[.!?]'), end);
        if (breakPoint > start) end = breakPoint + 1;
      } else {
        end = text.length;
      }
      chunks.add(text.substring(start, end).trim());
      start = end;
    }
    return chunks;
  }
}