import '../models/book_session.dart';
import '../models/companion.dart';

// ─────────────────────────────────────────────────────────────
//  PromptBuilder
//  Assembles the complete system prompt injected into every
//  API call from: persona base + verbosity + response mode +
//  book context + book map + custom note.
// ─────────────────────────────────────────────────────────────
class PromptBuilder {
  static String buildSystemPrompt(BookSession session) {
    final config = session.companionConfig;
    final companion = config.type;
    final buf = StringBuffer();

    buf.writeln(companion.baseSystemPrompt.trim());
    buf.writeln();

    buf.writeln('=== Response length ===');
    buf.writeln(config.verbosity.promptInstruction);
    buf.writeln();

    buf.writeln('=== Interaction style ===');
    switch (config.responseMode) {
      case ResponseMode.socratic:
        buf.writeln(
          'After answering, ask one thoughtful follow-up question to deepen '
          'the reader\'s engagement with the text. Do not ask two questions.',
        );
      case ResponseMode.proactive:
        buf.writeln(
          'Occasionally surface insights the reader hasn\'t asked for — '
          'but only when they are genuinely illuminating. Do not pad responses.',
        );
      case ResponseMode.informative:
        buf.writeln('Answer questions directly and completely.');
    }
    buf.writeln();

    buf.writeln('=== Current book ===');
    buf.writeln('Title: ${session.bookTitle}');
    buf.writeln('Author: ${session.bookAuthor}');
    if (session.genre.isNotEmpty) buf.writeln('Genre: ${session.genre}');
    if (session.readerGoal.isNotEmpty) {
      buf.writeln('Reader\'s goal: ${session.readerGoal}');
    }
    final pct = (session.progressPercent * 100).toStringAsFixed(0);
    buf.writeln('Reader\'s current progress: $pct% through the book');
    buf.writeln();

    if (session.hasBookContext) {
      buf.writeln('=== Book summary (background scan) ===');
      buf.writeln(session.bookMapSummary);
      buf.writeln(
        'Use this to give answers that consider the whole book, not just the '
        'current passage. If the answer to a question is in a part of the book '
        'the reader has not yet reached, warn them of the spoiler before answering.',
      );
      buf.writeln();
    }

    if (config.citeSources) {
      buf.writeln('=== Source attribution ===');
      buf.writeln(
        'If your answer draws on knowledge outside this book, explicitly say so: '
        '"This goes beyond the book — " and then give your answer. '
        'Never blend book content and external knowledge without distinguishing them.',
      );
      buf.writeln();
    }

    if (config.showConfidence) {
      buf.writeln('=== Confidence ===');
      buf.writeln(
        'When you are uncertain about something, say so clearly. '
        'Prefer "I think" or "I\'m not certain" over confident-sounding guesses.',
      );
      buf.writeln();
    }

    if (config.customPersonaNote != null &&
        config.customPersonaNote!.isNotEmpty) {
      buf.writeln('=== Custom instruction from reader ===');
      buf.writeln(config.customPersonaNote);
      buf.writeln();
    }

    return buf.toString().trim();
  }

  static String summarise(String passage, CompanionConfig config) {
    final style = _styleHint(config.type);
    return '''
Summarise the following passage in 3–5 sentences. $style
Do not use bullet points. Write in plain English.

Passage:
"$passage"
''';
  }

  static String explain(String passage, CompanionConfig config) {
    final style = _styleHint(config.type);
    return '''
Explain the following passage as if talking to a curious reader. $style
Use an analogy if it helps. Keep it under ${_wordLimit(config.verbosity)} words.

Passage:
"$passage"
''';
  }

  static String keyConcepts(String passage) {
    return '''
Extract 3–5 key concepts or terms from this passage.
Return ONLY the concepts, one per line, no numbering, no explanation.

Passage:
"$passage"
''';
  }

  static String ask(
    String passage,
    String question,
    CompanionConfig config,
    String? bookMapSummary,
  ) {
    final style = _styleHint(config.type);
    final bookContext =
        bookMapSummary != null ? '\nFull book context:\n$bookMapSummary\n' : '';
    return '''
A reader is asking a question about a passage they just read. $style
Answer using information from the passage first, then the broader book context if needed.
If the answer is not in the book at all, say "This goes beyond the book —" and then answer.
Keep your answer under ${_wordLimit(config.verbosity)} words.
$bookContext
Passage:
"$passage"

Question: $question
''';
  }

  static String conceptMap(String passage) {
    return '''
Return ONLY valid JSON. No explanation, no markdown fences.
Build a concept map from this passage:
{
  "central": "main idea (max 5 words)",
  "nodes": ["concept1", "concept2", "concept3"],
  "connections": [
    {"from": "central", "to": "concept1", "label": "short verb phrase"}
  ]
}
Maximum 5 nodes. Maximum 7 connections. Keep labels under 4 words.

Passage:
"$passage"
''';
  }

  static String proactiveNudge(
    String passage,
    String bookTitle,
    double progress,
    CompanionType type,
  ) {
    final pct = (progress * 100).toStringAsFixed(0);
    return '''
You are ${type.displayName}, reading alongside someone who is $pct% through "$bookTitle".
They just read this passage:
"$passage"

Without being asked, share ONE insight, connection, or question that would genuinely enrich their reading.
Be ${type.displayName == 'Spark' ? 'punchy and direct' : type.displayName == 'Sage' ? 'analytical and illuminating' : 'warm and perceptive'}.
Do not say "I noticed you're reading" or anything robotic. Just speak naturally.
Keep it under 80 words.
''';
  }

  static String _styleHint(CompanionType type) => switch (type) {
        CompanionType.sage =>
          'Be analytical and draw wider connections where relevant.',
        CompanionType.echo =>
          'Be warm and notice the emotional or human dimension first.',
        CompanionType.spark => 'Lead with the core point. Be direct and energetic.',
      };

  static int _wordLimit(Verbosity v) => switch (v) {
        Verbosity.concise => 60,
        Verbosity.moderate => 150,
        Verbosity.detailed => 300,
      };
}
