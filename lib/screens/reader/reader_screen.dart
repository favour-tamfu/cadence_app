import 'dart:async';
import 'dart:io';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../services/companion_session_manager.dart';
import '../../widgets/first_open_sheet.dart';
import '../../widgets/companion_panel.dart';

enum ReadingTheme { dark, sepia, light }

// Converts HTML character references and named entities to plain Unicode so
// extracted PDF/EPUB text never shows garbage like &ldquo; or &mdash;.
String _decodeHtmlEntities(String s) {
  return s
    // Typographic quotes & dashes -- the main culprits from PDF extraction
    .replaceAll('&ldquo;',  '\u201C') // left double quote
    .replaceAll('&rdquo;',  '\u201D') // right double quote
    .replaceAll('&lsquo;',  '\u2018') // left single quote
    .replaceAll('&rsquo;',  '\u2019') // right single quote / apostrophe
    .replaceAll('&mdash;',  '\u2014') // em dash
    .replaceAll('&ndash;',  '\u2013') // en dash
    .replaceAll('&hellip;', '\u2026') // horizontal ellipsis
    .replaceAll('&laquo;',  '\u00AB') // left angle quote
    .replaceAll('&raquo;',  '\u00BB') // right angle quote
    // Common inline entities
    .replaceAll('&bull;',   '\u2022') // bullet
    .replaceAll('&middot;', '\u00B7') // middle dot
    .replaceAll('&copy;',   '\u00A9') // copyright
    .replaceAll('&reg;',    '\u00AE') // registered
    .replaceAll('&trade;',  '\u2122') // trademark
    .replaceAll('&apos;',   "'")
    .replaceAll('&nbsp;',   ' ') // non-breaking space -> regular space
    .replaceAll('&shy;',    '')   // soft hyphen -- drop silently
    // Numeric decimal references: &#NNN;
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    })
    // Numeric hex references: &#xHHH;
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    })
    // Basic XML/HTML escapes -- do these last so we do not double-decode
    .replaceAll('&quot;',   '"')
    .replaceAll("&#39;",    "'")
    .replaceAll('&lt;',     '<')
    .replaceAll('&gt;',     '>')
    .replaceAll('&amp;',    '&');
}


class ReaderScreen extends StatefulWidget {
  final String bookTitle;
  final String fileUrl;
  final String fileType;
  final String libraryEntryId;
  final String bookId;
  final int initialPage;
  final int totalPages;

  const ReaderScreen({
    super.key,
    required this.bookTitle,
    required this.fileUrl,
    required this.fileType,
    required this.libraryEntryId,
    required this.bookId,
    required this.initialPage,
    required this.totalPages,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _supabase = Supabase.instance.client;

  // Loading state
  bool _isLoading = true;
  String? _errorMessage;
  int _extractionProgress = 0;
  String _loadingMessage = 'Opening your book...';

  // UI
  bool _barsVisible = true;
  bool _companionVisible = false;
  String _selectedText = '';
  int _lastNudgePage = -10;

  // Tap detection (Listener-based, bypasses gesture arena)
  DateTime? _tapDownTime;
  Offset? _tapDownPosition;
  Timer? _tapTimer;

  // Adobe content
  List<List<Map<String, dynamic>>> _adobePages = [];

  // Page tracking
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _totalPages = 0;
  int _lastSavedPage = 0;
  double _restoreScrollOffset = 0; // exact pixel offset saved on exit

  // Reading settings
  ReadingTheme _theme = ReadingTheme.dark;
  double _fontSize = 17;
  double _lineHeight = 1.8;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _totalPages = widget.totalPages;
    _loadBook();
    _saveLastOpened();

    // Show bars for 3s then hide
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _barsVisible = false);
    });
  }

  Future<void> _saveLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_entry', widget.libraryEntryId);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // â”€â”€ Theme helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Color get _bgColor {
    switch (_theme) {
      case ReadingTheme.sepia: return const Color(0xFFF8F0E3);
      case ReadingTheme.light: return const Color(0xFFFAFAFA);
      case ReadingTheme.dark:  return const Color(0xFF111827);
    }
  }

  Color get _textColor {
    switch (_theme) {
      case ReadingTheme.sepia: return const Color(0xFF3B2A1A);
      case ReadingTheme.light: return const Color(0xFF1A1A2E);
      case ReadingTheme.dark:  return const Color(0xFFE8E0D4);
    }
  }

  Color get _mutedColor {
    switch (_theme) {
      case ReadingTheme.sepia: return const Color(0xFF8B6F47);
      case ReadingTheme.light: return const Color(0xFF6B7280);
      case ReadingTheme.dark:  return AppColors.muted;
    }
  }

  Color get _overlayColor {
    switch (_theme) {
      case ReadingTheme.sepia: return const Color(0xFFF8F0E3).withValues(alpha: 0.97);
      case ReadingTheme.light: return Colors.white.withValues(alpha: 0.97);
      case ReadingTheme.dark:  return const Color(0xFF111827).withValues(alpha: 0.97);
    }
  }

  // â”€â”€ Load book â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Load saved scroll offset while book processes in the background.
    // The key is per library entry so each user-book pair has its own offset.
    final prefs = await SharedPreferences.getInstance();
    _restoreScrollOffset =
        prefs.getDouble('scroll_${widget.libraryEntryId}') ?? 0;

    try {
      if (widget.fileType == 'epub') {
        await _loadEpub();
      } else {
        await _loadPdfViaAdobe();
      }
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
      _openCompanionSession();
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load book.\n\n${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Jumps to the saved pixel offset, falling back to a page-proportion
  // estimate on first open (before any offset has been stored locally).
  void _restorePosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;

    final double target;
    if (_restoreScrollOffset > 0) {
      target = _restoreScrollOffset.clamp(0, max);
    } else if (widget.initialPage > 0 && _totalPages > 1) {
      target = (widget.initialPage / (_totalPages - 1)) * max;
    } else {
      return;
    }
    _scrollController.jumpTo(target);
  }

  // â”€â”€ Download file to local storage â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<File> _downloadFile(String ext) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.libraryEntryId}.$ext');

    if (widget.fileUrl.startsWith('http')) {
      final session = _supabase.auth.currentSession;
      final response = await http.get(
        Uri.parse(widget.fileUrl),
        headers: session != null
            ? {'Authorization': 'Bearer ${session.accessToken}'}
            : {},
      );
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
      await file.writeAsBytes(response.bodyBytes);
    } else {
      final bytes = await _supabase.storage
          .from('books')
          .download(widget.fileUrl);
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  // â”€â”€ Load EPUB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadEpub() async {
    setState(() => _loadingMessage = 'Loading EPUB...');
    final file = await _downloadFile('epub');
    final bytes = await file.readAsBytes();

    setState(() => _loadingMessage = 'Preparing content...');
    final book = await EpubDocument.openData(bytes);

    final allElements = <Map<String, dynamic>>[];

    void processChapter(EpubChapter chapter, int depth) {
      final title = chapter.Title?.trim() ?? '';
      if (title.isNotEmpty) {
        allElements.add({'type': depth == 0 ? 'h1' : 'h2', 'text': title});
      }
      final html = chapter.HtmlContent ?? '';
      if (html.isNotEmpty) {
        allElements.addAll(_extractTextFromHtml(html));
      }
      for (final sub in chapter.SubChapters ?? <EpubChapter>[]) {
        processChapter(sub, depth + 1);
      }
    }

    for (final chapter in book.Chapters ?? <EpubChapter>[]) {
      processChapter(chapter, 0);
    }

    _buildAdobePages({'elements': allElements, 'meta': {}});
  }

  // â”€â”€ Strip HTML and extract text elements â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Map<String, dynamic>> _extractTextFromHtml(String html) {
    final result = <Map<String, dynamic>>[];

    String clean(String s) => _decodeHtmlEntities(
            s.replaceAll(RegExp(r'<[^>]+>'), ''))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final blockRe = RegExp(
      r'<(h[1-6]|p|li|blockquote)(?:\s[^>]*)?>(.+?)<\/(?:h[1-6]|p|li|blockquote)>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final m in blockRe.allMatches(html)) {
      final tag = m.group(1)!.toLowerCase();
      final text = clean(m.group(2)!);
      if (text.length < 3) continue;

      String type;
      if (tag == 'h1') {
        type = 'h1';
      } else if (tag == 'h2') {
        type = 'h2';
      } else if (tag.startsWith('h')) {
        type = 'h3';
      } else if (tag == 'li') {
        type = 'li';
      } else {
        type = 'p';
      }
      result.add({'type': type, 'text': text});
    }

    // Fallback: extract all text if no block elements matched
    if (result.isEmpty) {
      final text = clean(html);
      if (text.length > 5) result.add({'type': 'p', 'text': text});
    }

    return result;
  }

  // â”€â”€ Adobe PDF pipeline â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _loadPdfViaAdobe() async {
    setState(() => _loadingMessage = 'Starting extraction...');

    // Step 1: Start the job
    final jobId = await _startExtractionJob();
    if (jobId == null) {
      throw Exception(
        'Could not start extraction. Check your connection and try again.',
      );
    }

    // Step 2: Poll until done
    setState(() => _loadingMessage = 'Extracting layout...');
    final content = await _pollUntilDone(jobId);

    if (content == null) {
      throw Exception(
        'Extraction timed out or failed. Please try again.',
      );
    }

    // Step 3: Render
    _buildAdobePages(content);
  }

  // â”€â”€ Start extraction job via Edge Function â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<String?> _startExtractionJob() async {
    try {
      final hash = widget.fileUrl.hashCode.toString();

      final response = await _supabase.functions.invoke(
        'extract-start',
        body: {
          'book_id': widget.bookId,
          'file_path': widget.fileUrl,
          'pdf_hash': hash,
        },
      );

      if (response.status != 200) {
        debugPrint('extract-start error: ${response.data}');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      debugPrint('extract-start response: $data');
      return data['job_id'] as String?;
    } catch (e) {
      debugPrint('_startExtractionJob error: $e');
      return null;
    }
  }

  // â”€â”€ Poll extract-status every 3 seconds â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<Map<String, dynamic>?> _pollUntilDone(String jobId) async {
    const maxAttempts = 40; // 40 Ã— 3s = 2 minutes
    int attempts = 0;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 3));
      attempts++;

      try {
        final response = await _supabase.functions.invoke(
          'extract-status',
          body: {'job_id': jobId},
        );

        if (response.status != 200) continue;

        final data = response.data as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'processing';

        debugPrint('Poll $attempts â€” status: $status');

        if (status == 'done') {
          return data['content'] as Map<String, dynamic>?;
        }

        if (status == 'failed') return null;

        // Update progress indicator
        final progress = data['progress'] as int? ?? 0;
        if (mounted) {
          setState(() {
            _extractionProgress = progress;
            _loadingMessage = progress > 0
                ? 'Extracting layout... $progress%'
                : 'Processing with Adobe...';
          });
        }
      } catch (e) {
        debugPrint('Poll attempt $attempts error: $e');
      }
    }

    return null; // Timed out
  }

  // â”€â”€ Build page list from Adobe content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _buildAdobePages(Map<String, dynamic> content) {
    final elements = content['elements'] as List<dynamic>? ?? [];

    final List<List<Map<String, dynamic>>> pages = [];
    List<Map<String, dynamic>> currentPage = [];
    int charCount = 0;

    for (final el in elements) {
      final map = Map<String, dynamic>.from(el as Map);
      // Sanitise entities before any text reaches the UI
      if (map['text'] is String) {
        map['text'] = _decodeHtmlEntities(map['text'] as String);
      }
      final type = map['type'] as String? ?? 'p';
      final text = map['text'] as String? ?? '';

      // Start a new page at h1 headings (chapter breaks)
      if (type == 'h1' && currentPage.isNotEmpty) {
        pages.add(List.from(currentPage));
        currentPage = [];
        charCount = 0;
      }

      currentPage.add(map);
      charCount += text.length;

      // Also break at ~1400 chars to keep pages readable
      if (charCount >= 1400) {
        pages.add(List.from(currentPage));
        currentPage = [];
        charCount = 0;
      }
    }

    if (currentPage.isNotEmpty) pages.add(currentPage);

    setState(() {
      _adobePages = pages;
      _totalPages = pages.length;
    });

    // Save total pages to Supabase
    if (widget.bookId.isNotEmpty && pages.isNotEmpty) {
      _supabase.from('books')
          .update({'total_pages': pages.length})
          .eq('id', widget.bookId);
    }
  }

  // â”€â”€ Save progress â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _saveProgress(int page) async {
    if (page == _lastSavedPage) return;
    try {
      await _supabase.from('user_library').update({
        'reading_progress': page,
        if (page >= _totalPages - 1 && _totalPages > 0)
          'status': 'completed',
      }).eq('id', widget.libraryEntryId);

      // Update streak on first page save of the session
      if (_lastSavedPage == widget.initialPage) {
        _updateStreak(); // fire and forget — don't await
      }

      _lastSavedPage = page;
    } catch (e) {
      debugPrint('Save progress error: $e');
    }
  }

  // ── Update streak in profiles table ──────────────────────────────────────────
  // Requires a `last_read_date date` column on the profiles table in Supabase.
  Future<void> _updateStreak() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      final profile = await _supabase
          .from('profiles')
          .select('streak, last_read_date')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return;

      final lastReadStr = profile['last_read_date'] as String?;
      final currentStreak = profile['streak'] as int? ?? 0;

      int newStreak = currentStreak;

      if (lastReadStr == null) {
        // First time reading
        newStreak = 1;
      } else {
        final lastRead = DateTime.parse(lastReadStr);
        final lastReadDate = DateTime(
          lastRead.year, lastRead.month, lastRead.day,
        );
        final diff = todayDate.difference(lastReadDate).inDays;

        if (diff == 0) {
          // Already read today — no change
          return;
        } else if (diff == 1) {
          // Consecutive day — increment
          newStreak = currentStreak + 1;
        } else {
          // Missed a day — reset
          newStreak = 1;
        }
      }

      await _supabase.from('profiles').update({
        'streak': newStreak,
        'last_read_date': todayDate.toIso8601String(),
      }).eq('id', userId);

    } catch (e) {
      debugPrint('Streak update error: $e');
    }
  }

  Future<void> _saveAndPop() async {
    // Persist exact scroll offset so we can restore the precise position.
    if (_scrollController.hasClients) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
          'scroll_${widget.libraryEntryId}', _scrollController.offset);
    }

    try {
      await _supabase.from('user_library').update({
        'reading_progress': _currentPage,
        if (_currentPage >= _totalPages - 1 && _totalPages > 0)
          'status': 'completed',
      }).eq('id', widget.libraryEntryId);

      if (_totalPages > 0 && widget.bookId.isNotEmpty) {
        await _supabase.from('books')
            .update({'total_pages': _totalPages})
            .eq('id', widget.bookId);
      }
    } catch (e) {
      debugPrint('Final save error: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  // â”€â”€ Companion â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _extractFullText() {
    final buf = StringBuffer();
    for (final page in _adobePages) {
      for (final el in page) {
        final text = el['text'] as String? ?? '';
        if (text.isNotEmpty) buf.writeln(text);
      }
    }
    return buf.toString();
  }

  Future<void> _openCompanionSession() async {
    if (!mounted) return;
    final manager = context.read<CompanionSessionManager>();
    await manager.openSession(
      bookId: widget.bookId,
      title: widget.bookTitle,
      fullBookText: _extractFullText(),
    );
    if (!mounted) return;
    await FirstOpenSheet.showIfNeeded(context);
  }

  void _openCompanion({String selectedText = ''}) {
    setState(() {
      _selectedText = selectedText;
      _companionVisible = true;
    });
  }

  void _triggerNudge() {
    final manager = context.read<CompanionSessionManager>();
    if (manager.session == null || manager.isThinking || _companionVisible) return;
    if (!manager.session!.companionConfig.proactiveNudges) return;
    _openCompanion();
  }

  // â”€â”€ Settings sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _overlayColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              const SizedBox(height: 20),

              Text('Reading settings', style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 20, color: _textColor,
              )),

              const SizedBox(height: 24),

              // Theme
              Text('THEME', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                letterSpacing: 1.4, color: _mutedColor,
              )),
              const SizedBox(height: 12),
              Row(children: [
                _themeBtn(setSheet, ReadingTheme.dark, 'Dark',
                    const Color(0xFF111827), const Color(0xFFE8E0D4)),
                const SizedBox(width: 10),
                _themeBtn(setSheet, ReadingTheme.sepia, 'Sepia',
                    const Color(0xFFF8F0E3), const Color(0xFF3B2A1A)),
                const SizedBox(width: 10),
                _themeBtn(setSheet, ReadingTheme.light, 'Light',
                    const Color(0xFFFAFAFA), const Color(0xFF1A1A2E)),
              ]),

              const SizedBox(height: 24),

              // Font size
              Text('FONT SIZE', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                letterSpacing: 1.4, color: _mutedColor,
              )),
              const SizedBox(height: 8),
              Row(children: [
                Text('A', style: TextStyle(fontSize: 13, color: _mutedColor)),
                Expanded(child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.amber,
                    inactiveTrackColor: _mutedColor.withValues(alpha: 0.2),
                    thumbColor: AppColors.amber,
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _fontSize, min: 13, max: 24, divisions: 11,
                    onChanged: (v) {
                      setState(() => _fontSize = v);
                      setSheet(() {});
                    },
                  ),
                )),
                Text('A', style: TextStyle(fontSize: 22, color: _mutedColor)),
              ]),

              const SizedBox(height: 16),

              // Line spacing
              Text('LINE SPACING', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                letterSpacing: 1.4, color: _mutedColor,
              )),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.format_line_spacing_rounded,
                    size: 16, color: _mutedColor),
                Expanded(child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.amber,
                    inactiveTrackColor: _mutedColor.withValues(alpha: 0.2),
                    thumbColor: AppColors.amber,
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _lineHeight, min: 1.4, max: 2.4, divisions: 10,
                    onChanged: (v) {
                      setState(() => _lineHeight = v);
                      setSheet(() {});
                    },
                  ),
                )),
                Icon(Icons.format_line_spacing_rounded,
                    size: 22, color: _mutedColor),
              ]),

              // Page jump
              if (_totalPages > 1) ...[
                const SizedBox(height: 16),
                Text('JUMP TO PAGE', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500,
                  letterSpacing: 1.4, color: _mutedColor,
                )),
                const SizedBox(height: 8),
                Row(children: [
                  Text('1', style: TextStyle(fontSize: 12, color: _mutedColor)),
                  Expanded(child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.amber,
                      inactiveTrackColor: _mutedColor.withValues(alpha: 0.2),
                      thumbColor: AppColors.amber,
                      trackHeight: 3,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: _currentPage.toDouble().clamp(
                          0, (_totalPages - 1).toDouble()),
                      min: 0,
                      max: (_totalPages - 1).toDouble(),
                      onChanged: (v) async {
                        final page = v.round();
                        setState(() => _currentPage = page);
                        setSheet(() {});
                        if (_scrollController.hasClients &&
                            _scrollController.position.maxScrollExtent > 0 &&
                            _adobePages.length > 1) {
                          final offset = (page / (_adobePages.length - 1)) *
                              _scrollController.position.maxScrollExtent;
                          _scrollController.jumpTo(offset.clamp(
                              0.0, _scrollController.position.maxScrollExtent));
                        }
                        await _saveProgress(page);
                      },
                    ),
                  )),
                  Text('$_totalPages',
                      style: TextStyle(fontSize: 12, color: _mutedColor)),
                ]),
              ],

            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _themeBtn(StateSetter setSheet, ReadingTheme theme,
      String label, Color bg, Color text) {
    final active = _theme == theme;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _theme = theme);
          setSheet(() {});
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.amber : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Aa', style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 20, color: text,
              )),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(
                fontSize: 10,
                color: text.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        body: _isLoading
            ? _buildLoading()
            : _errorMessage != null
            ? _buildError()
            : Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _tapTimer?.cancel();
            _tapDownTime = DateTime.now();
            _tapDownPosition = e.position;
          },
          onPointerUp: (e) {
            if (_tapDownTime == null) return;
            final ms = DateTime.now().difference(_tapDownTime!).inMilliseconds;
            final dist = _tapDownPosition == null
                ? 999.0
                : (e.position - _tapDownPosition!).distance;
            _tapDownTime = null;
            _tapDownPosition = null;
            if (ms < 200 && dist < 20) {
              // Start timer â€” cancelled by a second pointerDown (double-tap)
              _tapTimer = Timer(const Duration(milliseconds: 250), () {
                if (mounted) setState(() => _barsVisible = !_barsVisible);
              });
            }
          },
          child: Stack(children: [

            // Main reading area
            _buildAdobeReader(),

            // Companion panel overlay
            if (_companionVisible)
              Positioned.fill(
                child: CompanionPanel(
                  selectedText: _selectedText,
                  onClose: () => setState(() {
                    _companionVisible = false;
                    _selectedText = '';
                  }),
                ),
              ),

            // Top bar
            if (!_companionVisible)
              AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                offset: _barsVisible
                    ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _barsVisible ? 1 : 0,
                  child: _buildTopBar(context),
                ),
              ),

            // Bottom bar
            if (!_companionVisible)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  offset: _barsVisible
                      ? Offset.zero : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _barsVisible ? 1 : 0,
                    child: _buildBottomBar(),
                  ),
                ),
              ),

            // ✦ Companion trigger button (visible during reading)
            if (!_companionVisible)
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 72,
                child: GestureDetector(
                  onTap: () => _openCompanion(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.midnight2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '✦',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

          ]),
        ),
      ),
    );
  }

  // â”€â”€ Adobe page reader â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildAdobeReader() {
    if (_adobePages.isEmpty) {
      return Center(
        child: Text(
          'No content to display.',
          style: TextStyle(color: _mutedColor, fontSize: 14),
        ),
      );
    }

    return SelectionArea(
      contextMenuBuilder: (ctx, state) =>
          AdaptiveTextSelectionToolbar.buttonItems(
        anchors: state.contextMenuAnchors,
        buttonItems: [
          ...state.contextMenuButtonItems,
          ContextMenuButtonItem(
            label: 'Ask Companion',
            onPressed: () {
              // Trigger native copy, then read clipboard to get selected text
              final copyItem = state.contextMenuButtonItems.firstWhere(
                (item) => item.type == ContextMenuButtonType.copy,
                orElse: () =>
                    ContextMenuButtonItem(onPressed: () {}, label: ''),
              );
              copyItem.onPressed?.call();
              ContextMenuController.removeAny();
              Future.delayed(const Duration(milliseconds: 50), () async {
                if (!mounted) return;
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text?.trim() ?? '';
                if (text.isNotEmpty) _openCompanion(selectedText: text);
              });
            },
          ),
        ],
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.metrics.maxScrollExtent > 0 &&
              _adobePages.length > 1) {
            final pct = (notification.metrics.pixels /
                    notification.metrics.maxScrollExtent)
                .clamp(0.0, 1.0);
            final page = (pct * (_adobePages.length - 1)).round();
            if (page != _currentPage) {
              setState(() => _currentPage = page);
              _saveProgress(page);
              if (page - _lastNudgePage >= 10) {
                _lastNudgePage = page;
                _triggerNudge();
              }
            }
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _adobePages.length,
          itemBuilder: (ctx, index) =>
              _buildAdobePage(_adobePages[index], index),
        ),
      ),
    );
  }

  Widget _buildAdobePage(List<Map<String, dynamic>> elements, int index) {
    final topPad = MediaQuery.of(context).padding.top + 72;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index == 0) SizedBox(height: topPad),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: elements.map((el) {
              final type = el['type'] as String? ?? 'p';
              final text = el['text'] as String? ?? '';

              switch (type) {
                case 'h1':
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Text(text, style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: _fontSize + 8,
                      color: _textColor,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    )),
                  );
                case 'h2':
                  return Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    child: Text(text, style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: _fontSize + 4,
                      color: _textColor,
                      height: 1.3,
                    )),
                  );
                case 'h3':
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(text, style: TextStyle(
                      fontSize: _fontSize + 1,
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    )),
                  );
                case 'li':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('â€¢ ', style: TextStyle(
                          color: AppColors.amberLight,
                          fontSize: _fontSize,
                        )),
                        Expanded(child: Text(text, style: TextStyle(
                          fontSize: _fontSize,
                          color: _textColor,
                          height: _lineHeight,
                        ))),
                      ],
                    ),
                  );
                default:
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(text, style: TextStyle(
                      fontSize: _fontSize,
                      color: _textColor,
                      height: _lineHeight,
                      letterSpacing: 0.15,
                      wordSpacing: 0.5,
                    )),
                  );
              }
            }).toList(),
          ),
        ),
        if (index < _adobePages.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
            child: Divider(color: _mutedColor.withValues(alpha: 0.12), height: 1),
          ),
        if (index == _adobePages.length - 1)
          const SizedBox(height: 100),
      ],
    );
  }

  // â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: _overlayColor,
      padding: EdgeInsets.fromLTRB(
        16, MediaQuery.of(context).padding.top + 8, 16, 12,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _saveAndPop,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: _textColor, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.bookTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showSettings,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.tune_rounded, color: _textColor, size: 18),
          ),
        ),
      ]),
    );
  }

  // â”€â”€ Bottom bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBottomBar() {
    final progress = _totalPages > 0
        ? (_currentPage + 1) / _totalPages
        : 0.0;

    return Container(
      color: _overlayColor,
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: _mutedColor.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_currentPage + 1}',
                style: TextStyle(fontSize: 11, color: _mutedColor),
              ),
              Text(
                '${(progress * 100).round()}% complete',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.amberLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_totalPages pages',
                style: TextStyle(fontSize: 11, color: _mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ Loading state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.amber, strokeWidth: 2,
              ),
              const SizedBox(height: 20),
              Text(
                _loadingMessage,
                style: TextStyle(fontSize: 14, color: _mutedColor),
                textAlign: TextAlign.center,
              ),
              if (_extractionProgress > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _extractionProgress / 100,
                    minHeight: 3,
                    backgroundColor: _mutedColor.withValues(alpha: 0.2),
                    valueColor:
                    const AlwaysStoppedAnimation(AppColors.amber),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_extractionProgress%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.amberLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Error state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildError() {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: _mutedColor.withValues(alpha: 0.5)),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, color: _mutedColor, height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _loadBook,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Try again',
                    style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
