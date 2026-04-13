import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';

class ReaderScreen extends StatefulWidget {
  final String bookTitle;
  final String fileUrl;
  final String libraryEntryId;
  final int initialPage;
  final int totalPages;

  const ReaderScreen({
    super.key,
    required this.bookTitle,
    required this.fileUrl,
    required this.libraryEntryId,
    required this.initialPage,
    required this.totalPages,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _supabase = Supabase.instance.client;

  // PDF controller
  PDFViewController? _pdfController;

  // Tracking state
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  bool _isDownloading = true;
  String? _localPath;
  String? _errorMessage;

  // We save to Supabase every 5 pages
  int _lastSavedPage = 0;

  // Toggle top/bottom bars visibility
  bool _barsVisible = true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _totalPages = widget.totalPages;
    _downloadPdf();
  }

  // ── DOWNLOAD PDF TO LOCAL STORAGE ─────────────────────────────────────────
  // PDFView needs a local file path — it can't stream from a URL directly
  Future<void> _downloadPdf() async {
    try {
      setState(() => _isDownloading = true);

      final response = await http.get(Uri.parse(widget.fileUrl));

      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Could not load the PDF. Please try again.';
          _isDownloading = false;
        });
        return;
      }

      // Save to temp directory
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.libraryEntryId}.pdf');
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _localPath = file.path;
        _isDownloading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load PDF: ${e.toString()}';
        _isDownloading = false;
      });
    }
  }

  // ── SAVE PROGRESS TO SUPABASE ─────────────────────────────────────────────
  Future<void> _saveProgress(int page) async {
    // Only save every 5 pages to avoid too many writes
    if ((page - _lastSavedPage).abs() < 5 && page != _totalPages - 1) return;

    try {
      await _supabase
          .from('user_library')
          .update({
        'reading_progress': page,
        // Mark as completed if on last page
        if (page >= _totalPages - 1) 'status': 'completed',
      })
          .eq('id', widget.libraryEntryId);

      _lastSavedPage = page;
    } catch (e) {
      // Silent fail — don't interrupt reading for a save error
      debugPrint('Progress save failed: $e');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: [

          // ── PDF viewer (full screen)
          if (_isDownloading)
            _buildLoadingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_localPath != null)
              GestureDetector(
                // Tap anywhere to toggle bars
                onTap: () => setState(() => _barsVisible = !_barsVisible),
                child: PDFView(
                  filePath: _localPath!,
                  defaultPage: widget.initialPage,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  pageSnap: true,
                  backgroundColor: AppColors.midnight,
                  onRender: (pages) {
                    setState(() {
                      _totalPages = pages ?? widget.totalPages;
                      _isReady = true;
                    });
                  },
                  onViewCreated: (controller) {
                    _pdfController = controller;
                  },
                  onPageChanged: (page, total) {
                    if (page == null) return;
                    setState(() => _currentPage = page);
                    _saveProgress(page);
                  },
                  onError: (e) {
                    setState(() {
                      _errorMessage = 'Error rendering PDF.';
                    });
                  },
                ),
              ),

          // ── Top bar
          AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: _barsVisible ? Offset.zero : const Offset(0, -1),
            child: _buildTopBar(context),
          ),

          // ── Bottom bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: _barsVisible ? Offset.zero : const Offset(0, 1),
              child: _buildBottomBar(),
            ),
          ),

        ],
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: AppColors.midnight.withOpacity(0.95),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        12,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.cream.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.cream,
                size: 16,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Book title
          Expanded(
            child: Text(
              widget.bookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.cream,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Page count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cream.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _isReady
                  ? '${_currentPage + 1} / $_totalPages'
                  : '...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM BAR ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final progress = _totalPages > 0
        ? (_currentPage + 1) / _totalPages
        : 0.0;

    return Container(
      color: AppColors.midnight.withOpacity(0.95),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: AppColors.cream.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_currentPage + 1}',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Text(
                '${(progress * 100).round()}% complete',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.amberLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_totalPages pages',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LOADING STATE ──────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.amber,
            strokeWidth: 2,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your book...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR STATE ────────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.muted.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _downloadPdf,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}