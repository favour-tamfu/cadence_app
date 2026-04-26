import 'dart:async';
import 'dart:io';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

enum ReadingTheme { dark, sepia, light }

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

  // Tap detection (Listener-based, bypasses gesture arena)
  DateTime? _tapDownTime;
  Offset? _tapDownPosition;
  Timer? _tapTimer;

  // Selection
  final FocusNode _pdfFocusNode = FocusNode();
  final FocusNode _epubFocusNode = FocusNode();

  // EPUB
  EpubController? _epubController;

  // Adobe content
  List<List<Map<String, dynamic>>> _adobePages = [];

  // Page tracking
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  int _totalPages = 0;
  int _lastSavedPage = 0;

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

    // Show bars for 3s then hide
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _barsVisible = false);
    });
  }

  @override
  void dispose() {
    _epubController?.dispose();
    _pdfFocusNode.dispose();
    _epubFocusNode.dispose();
    _tapTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Theme helpers ─────────────────────────────────────────────────────────
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
      case ReadingTheme.sepia: return const Color(0xFFF8F0E3).withOpacity(0.97);
      case ReadingTheme.light: return Colors.white.withOpacity(0.97);
      case ReadingTheme.dark:  return const Color(0xFF111827).withOpacity(0.97);
    }
  }

  // ── Load book ─────────────────────────────────────────────────────────────
  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.fileType == 'epub') {
        await _loadEpub();
      } else {
        await _loadPdfViaAdobe();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load book.\n\n${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ── Download file to local storage ────────────────────────────────────────
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

  // ── Load EPUB ─────────────────────────────────────────────────────────────
  Future<void> _loadEpub() async {
    setState(() => _loadingMessage = 'Loading EPUB...');
    final file = await _downloadFile('epub');
    final bytes = await file.readAsBytes();
    _epubController = EpubController(
      document: EpubDocument.openData(bytes),
    );
  }

  // ── Adobe PDF pipeline ────────────────────────────────────────────────────
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

  // ── Start extraction job via Edge Function ────────────────────────────────
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

  // ── Poll extract-status every 3 seconds ───────────────────────────────────
  Future<Map<String, dynamic>?> _pollUntilDone(String jobId) async {
    const maxAttempts = 40; // 40 × 3s = 2 minutes
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

        debugPrint('Poll $attempts — status: $status');

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

  // ── Build page list from Adobe content ────────────────────────────────────
  void _buildAdobePages(Map<String, dynamic> content) {
    final elements = content['elements'] as List<dynamic>? ?? [];

    final List<List<Map<String, dynamic>>> pages = [];
    List<Map<String, dynamic>> currentPage = [];
    int charCount = 0;

    for (final el in elements) {
      final map = Map<String, dynamic>.from(el as Map);
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

    // Restore saved position
    if (widget.initialPage > 0 && widget.initialPage < pages.length) {
      _currentPage = widget.initialPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0 &&
            pages.length > 1) {
          final offset = (widget.initialPage / (pages.length - 1)) *
              _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(
              offset.clamp(0.0, _scrollController.position.maxScrollExtent));
        }
      });
    }

    // Save total pages to Supabase
    if (widget.bookId.isNotEmpty && pages.isNotEmpty) {
      _supabase.from('books')
          .update({'total_pages': pages.length})
          .eq('id', widget.bookId);
    }
  }

  // ── Save progress ─────────────────────────────────────────────────────────
  Future<void> _saveProgress(int page) async {
    if ((page - _lastSavedPage).abs() < 3 &&
        page != _totalPages - 1) return;
    try {
      await _supabase.from('user_library').update({
        'reading_progress': page,
        if (page >= _totalPages - 1 && _totalPages > 0)
          'status': 'completed',
      }).eq('id', widget.libraryEntryId);
      _lastSavedPage = page;
    } catch (e) {
      debugPrint('Save progress error: $e');
    }
  }

  Future<void> _saveAndPop() async {
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

  // ── Settings sheet ────────────────────────────────────────────────────────
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
                  color: _mutedColor.withOpacity(0.3),
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
                    inactiveTrackColor: _mutedColor.withOpacity(0.2),
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
                    inactiveTrackColor: _mutedColor.withOpacity(0.2),
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
                      inactiveTrackColor: _mutedColor.withOpacity(0.2),
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
                color: text.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
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
              // Start timer — cancelled by a second pointerDown (double-tap)
              _tapTimer = Timer(const Duration(milliseconds: 250), () {
                if (mounted) setState(() => _barsVisible = !_barsVisible);
              });
            }
          },
          child: Stack(children: [

            // Main reading area
            widget.fileType == 'epub'
                ? _buildEpubReader()
                : _buildAdobeReader(),

            // Top bar
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

          ]),
        ),
      ),
    );
  }

  // ── EPUB reader ───────────────────────────────────────────────────────────
  Widget _buildEpubReader() {
    if (_epubController == null) return const SizedBox();
    return SelectableRegion(
      focusNode: _epubFocusNode,
      selectionControls: materialTextSelectionControls,
      child: EpubView(
        controller: _epubController!,
        builders: EpubViewBuilders<DefaultBuilderOptions>(
          options: DefaultBuilderOptions(
            textStyle: TextStyle(
              fontSize: _fontSize,
              color: _textColor,
              height: _lineHeight,
              letterSpacing: 0.2,
            ),
          ),
          chapterDividerBuilder: (_) => Divider(
            color: _mutedColor.withOpacity(0.2),
            height: 40,
          ),
        ),
        onChapterChanged: (value) {
          if (value == null) return;
          setState(() => _currentPage = value.chapterNumber);
          _saveProgress(_currentPage);
        },
      ),
    );
  }

  // ── Adobe page reader ─────────────────────────────────────────────────────
  Widget _buildAdobeReader() {
    if (_adobePages.isEmpty) {
      return Center(
        child: Text(
          'No content to display.',
          style: TextStyle(color: _mutedColor, fontSize: 14),
        ),
      );
    }

    return SelectableRegion(
      focusNode: _pdfFocusNode,
      selectionControls: materialTextSelectionControls,
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
                        Text('• ', style: TextStyle(
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
            child: Divider(color: _mutedColor.withOpacity(0.12), height: 1),
          ),
        if (index == _adobePages.length - 1)
          const SizedBox(height: 100),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
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
              color: _textColor.withOpacity(0.08),
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
              color: _textColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.tune_rounded, color: _textColor, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
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
              backgroundColor: _mutedColor.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.fileType == 'epub'
                    ? 'Chapter $_currentPage'
                    : 'Page ${_currentPage + 1}',
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
                '$_totalPages ${widget.fileType == 'epub' ? 'chapters' : 'pages'}',
                style: TextStyle(fontSize: 11, color: _mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────
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
                    backgroundColor: _mutedColor.withOpacity(0.2),
                    valueColor:
                    const AlwaysStoppedAnimation(AppColors.amber),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_extractionProgress%',
                  style: TextStyle(
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

  // ── Error state ───────────────────────────────────────────────────────────
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
                  size: 48, color: _mutedColor.withOpacity(0.5)),
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