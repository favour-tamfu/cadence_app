import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Verbosity
// ─────────────────────────────────────────────────────────────
enum Verbosity {
  concise,
  moderate,
  detailed;

  String get label => switch (this) {
        Verbosity.concise => 'Concise',
        Verbosity.moderate => 'Moderate',
        Verbosity.detailed => 'Detailed',
      };

  String get description => switch (this) {
        Verbosity.concise => 'Quick, punchy answers — under 60 words',
        Verbosity.moderate => 'Balanced — clear without being long',
        Verbosity.detailed => 'In-depth — full context and nuance',
      };

  String get promptInstruction => switch (this) {
        Verbosity.concise => 'Keep every response under 60 words. Be direct.',
        Verbosity.moderate =>
          'Keep responses between 80–150 words. Be clear and complete.',
        Verbosity.detailed =>
          'You may use up to 300 words. Be thorough and nuanced.',
      };
}

// ─────────────────────────────────────────────────────────────
//  Response mode
// ─────────────────────────────────────────────────────────────
enum ResponseMode {
  informative,
  socratic,
  proactive;

  String get label => switch (this) {
        ResponseMode.informative => 'Informative',
        ResponseMode.socratic => 'Socratic',
        ResponseMode.proactive => 'Proactive',
      };

  String get description => switch (this) {
        ResponseMode.informative => 'Answers your questions directly',
        ResponseMode.socratic => 'Guides you with questions to deepen thinking',
        ResponseMode.proactive => 'Surfaces insights without being asked',
      };
}

// ─────────────────────────────────────────────────────────────
//  Companion type
// ─────────────────────────────────────────────────────────────
enum CompanionType {
  sage,
  echo,
  spark;

  String get displayName => switch (this) {
        CompanionType.sage => 'Sage',
        CompanionType.echo => 'Echo',
        CompanionType.spark => 'Spark',
      };

  String get tagline => switch (this) {
        CompanionType.sage => 'Deep & analytical',
        CompanionType.echo => 'Warm & conversational',
        CompanionType.spark => 'Playful & concise',
      };

  String get description => switch (this) {
        CompanionType.sage =>
          'A scholarly companion who connects ideas across disciplines, challenges assumptions, and brings academic rigour to every passage.',
        CompanionType.echo =>
          'An emotionally attuned companion who notices character dynamics, asks how a passage made you feel, and reads between the lines.',
        CompanionType.spark =>
          'An energetic coach who cuts to the core idea fast, uses modern analogies, and keeps you moving through the book.',
      };

  List<String> get suitedGenres => switch (this) {
        CompanionType.sage => [
            'Non-fiction',
            'Philosophy',
            'History',
            'Science',
            'Biography',
          ],
        CompanionType.echo => [
            'Literary fiction',
            'Memoir',
            'Romance',
            'Poetry',
            'Short stories',
          ],
        CompanionType.spark => [
            'Self-help',
            'Young Adult',
            'Business',
            'Thriller',
            'Essays',
          ],
      };

  // Companion identity colours — these are NOT AppColors, they're persona brand colours
  Color get primaryColor => switch (this) {
        CompanionType.sage => const Color(0xFF534AB7),
        CompanionType.echo => const Color(0xFF0F6E56),
        CompanionType.spark => const Color(0xFF993C1D),
      };

  // Light variant — safe to use as text/icon on dark backgrounds
  Color get lightColor => switch (this) {
        CompanionType.sage => const Color(0xFFEEEDFE),
        CompanionType.echo => const Color(0xFFE1F5EE),
        CompanionType.spark => const Color(0xFFFAECE7),
      };

  Color get darkColor => switch (this) {
        CompanionType.sage => const Color(0xFF3C3489),
        CompanionType.echo => const Color(0xFF085041),
        CompanionType.spark => const Color(0xFF712B13),
      };

  String get voiceId => switch (this) {
        CompanionType.sage => 'en-US-Neural2-D',
        CompanionType.echo => 'en-US-Neural2-F',
        CompanionType.spark => 'en-US-Neural2-J',
      };

  String get baseSystemPrompt => switch (this) {
        CompanionType.sage => '''
You are Sage, an AI reading companion inside the Cadence reading app.
Your personality: scholarly, precise, intellectually curious. You draw connections across disciplines — history, philosophy, science — when they illuminate the text. You challenge comfortable assumptions with care. You speak in full, well-formed paragraphs. You never oversimplify.
Your tone: think "brilliant professor who actually enjoys talking to students."
When you reference ideas outside the book, you always say so clearly.
Never use bullet points unless the user explicitly asks for a list.
''',
        CompanionType.echo => '''
You are Echo, an AI reading companion inside the Cadence reading app.
Your personality: warm, empathetic, emotionally intelligent. You notice what a passage *feels* like before what it *means*. You pay attention to character voice, relationship dynamics, and the emotion between the lines. You often reflect a feeling back before offering analysis.
Your tone: think "thoughtful best friend who has read everything and listens well."
When you reference ideas outside the book, you always say so clearly.
Never be clinical or detached. Humanity first.
''',
        CompanionType.spark => '''
You are Spark, an AI reading companion inside the Cadence reading app.
Your personality: energetic, direct, encouraging. You get to the core idea fast and make it stick with a punchy analogy or a modern reference. You celebrate progress. You're not shallow — you're efficient.
Your tone: think "brilliant coach who respects your time."
When you reference ideas outside the book, you always say so clearly.
Lead with the punchline. Earn the detail.
''',
      };
}

// ─────────────────────────────────────────────────────────────
//  CompanionConfig
// ─────────────────────────────────────────────────────────────
class CompanionConfig {
  final CompanionType type;
  final Verbosity verbosity;
  final ResponseMode responseMode;
  final bool voiceEnabled;
  final bool proactiveNudges;
  final bool socraticMode;
  final String? customPersonaNote;
  final bool citeSources;
  final bool showConfidence;

  const CompanionConfig({
    required this.type,
    this.verbosity = Verbosity.moderate,
    this.responseMode = ResponseMode.informative,
    this.voiceEnabled = false,
    this.proactiveNudges = true,
    this.socraticMode = false,
    this.customPersonaNote,
    this.citeSources = true,
    this.showConfidence = false,
  });

  CompanionConfig copyWith({
    CompanionType? type,
    Verbosity? verbosity,
    ResponseMode? responseMode,
    bool? voiceEnabled,
    bool? proactiveNudges,
    bool? socraticMode,
    String? customPersonaNote,
    bool? citeSources,
    bool? showConfidence,
  }) {
    return CompanionConfig(
      type: type ?? this.type,
      verbosity: verbosity ?? this.verbosity,
      responseMode: responseMode ?? this.responseMode,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      proactiveNudges: proactiveNudges ?? this.proactiveNudges,
      socraticMode: socraticMode ?? this.socraticMode,
      customPersonaNote: customPersonaNote ?? this.customPersonaNote,
      citeSources: citeSources ?? this.citeSources,
      showConfidence: showConfidence ?? this.showConfidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'verbosity': verbosity.name,
        'responseMode': responseMode.name,
        'voiceEnabled': voiceEnabled,
        'proactiveNudges': proactiveNudges,
        'socraticMode': socraticMode,
        'customPersonaNote': customPersonaNote,
        'citeSources': citeSources,
        'showConfidence': showConfidence,
      };

  factory CompanionConfig.fromJson(Map<String, dynamic> json) {
    return CompanionConfig(
      type: CompanionType.values.byName(json['type'] as String),
      verbosity: Verbosity.values.byName(
        json['verbosity'] as String? ?? 'moderate',
      ),
      responseMode: ResponseMode.values.byName(
        json['responseMode'] as String? ?? 'informative',
      ),
      voiceEnabled: json['voiceEnabled'] as bool? ?? false,
      proactiveNudges: json['proactiveNudges'] as bool? ?? true,
      socraticMode: json['socraticMode'] as bool? ?? false,
      customPersonaNote: json['customPersonaNote'] as String?,
      citeSources: json['citeSources'] as bool? ?? true,
      showConfidence: json['showConfidence'] as bool? ?? false,
    );
  }

  factory CompanionConfig.defaultFor(CompanionType type) {
    return CompanionConfig(
      type: type,
      verbosity: switch (type) {
        CompanionType.sage => Verbosity.detailed,
        CompanionType.echo => Verbosity.moderate,
        CompanionType.spark => Verbosity.concise,
      },
      responseMode: switch (type) {
        CompanionType.sage => ResponseMode.socratic,
        CompanionType.echo => ResponseMode.informative,
        CompanionType.spark => ResponseMode.informative,
      },
    );
  }
}
