import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../reader/reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _supabase = Supabase.instance.client;

  // Currently selected filter
  String _selectedFilter = 'All';

  // All filter options
  final List<String> _filters = [
    'All', 'Reading', 'Completed', 'Uploads', 'Wishlist'
  ];

  // Books loaded from Supabase
  List<Map<String, dynamic>> _books = [];

  // Whether we are loading or uploading
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  // ── LOAD BOOKS FROM SUPABASE ───────────────────────────────────────────────
  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      // Join user_library with books to get full book details
      final response = await _supabase
          .from('user_library')
          .select('*, books(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _books = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load library: $e'),
            backgroundColor: AppColors.midnight3,
          ),
        );
      }
    }
  }

  // ── UPLOAD PDF ─────────────────────────────────────────────────────────────
  Future<void> _uploadBook() async {
    // Open the device file picker — PDF only
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileId = const Uuid().v4();
      final fileName = '$fileId.pdf';
      final filePath = 'users/$userId/books/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('books')
          .upload(filePath, File(file.path!));

      // Get the public/signed URL
      final fileUrl = _supabase.storage
          .from('books')
          .getPublicUrl(filePath);

      // Save book record to Firestore books table
      final bookResponse = await _supabase
          .from('books')
          .insert({
        'title': _cleanTitle(file.name),
        'author': 'Unknown',
        'uploaded_by': userId,
        'file_url': fileUrl,
        'total_pages': 0,
        'is_public': false,
      })
          .select()
          .single();

      // Add to user_library join table
      await _supabase.from('user_library').insert({
        'user_id': userId,
        'book_id': bookResponse['id'],
        'reading_progress': 0,
        'status': 'reading',
      });

      // Reload the library
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_cleanTitle(file.name)} added to your library.',
              style: const TextStyle(color: AppColors.cream),
            ),
            backgroundColor: AppColors.midnight3,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString()}',
              style: const TextStyle(color: Color(0xFFF09595)),
            ),
            backgroundColor: AppColors.midnight3,
          ),
        );
      }
    }
  }

  // Cleans up file name into a readable book title
  String _cleanTitle(String fileName) {
    return fileName
        .replaceAll('.pdf', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
  }

  // ── FILTER BOOKS ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredBooks {
    if (_selectedFilter == 'All') return _books;
    return _books.where((entry) {
      final status = entry['status'] as String? ?? 'reading';
      switch (_selectedFilter) {
        case 'Reading':   return status == 'reading';
        case 'Completed': return status == 'completed';
        case 'Wishlist':  return status == 'wishlist';
        case 'Uploads':   return entry['books']?['is_public'] == false;
        default:          return true;
      }
    }).toList();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Text(
                    'My Library',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 30,
                      color: AppColors.cream,
                    ),
                  ),
                  const Spacer(),
                  // Upload button
                  GestureDetector(
                    onTap: _isUploading ? null : _uploadBook,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploading
                          ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Filter pills
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filters.length,
                itemBuilder: (ctx, i) {
                  final filter = _filters[i];
                  final isActive = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.amber
                            : AppColors.cream.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? AppColors.amber
                              : AppColors.cream.withOpacity(0.12),
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isActive ? Colors.white : AppColors.muted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Book list
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.amber,
                  strokeWidth: 2,
                ),
              )
                  : _filteredBooks.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.midnight2,
                onRefresh: _loadBooks,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _filteredBooks.length,
                  itemBuilder: (ctx, i) {
                    return _BookCard(
                      entry: _filteredBooks[i],
                      onDeleted: _loadBooks,
                    );
                  },
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final isFiltered = _selectedFilter != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 52,
              color: AppColors.muted.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(
              isFiltered
                  ? 'No ${_selectedFilter.toLowerCase()} books yet.'
                  : 'Your library is quiet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 22,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered
                  ? 'Change the filter or add a new book.'
                  : 'Tap the + button to upload your first PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _uploadBook,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Upload a book',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── BOOK CARD ─────────────────────────────────────────────────────────────────
class _BookCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDeleted;

  const _BookCard({required this.entry, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final book = entry['books'] as Map<String, dynamic>? ?? {};
    final title = book['title'] as String? ?? 'Untitled';
    final author = book['author'] as String? ?? 'Unknown';
    final totalPages = book['total_pages'] as int? ?? 0;
    final progress = entry['reading_progress'] as int? ?? 0;
    final status = entry['status'] as String? ?? 'reading';

    // Progress percentage — avoid divide by zero
    final pct = totalPages > 0 ? (progress / totalPages).clamp(0.0, 1.0) : 0.0;
    final pctLabel = totalPages > 0
        ? '${(pct * 100).round()}%'
        : 'No pages';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Book cover placeholder
          Container(
            width: 48, height: 66,
            decoration: BoxDecoration(
              color: AppColors.midnight3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.cream.withOpacity(0.08),
              ),
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'B',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 22,
                  color: AppColors.amberLight,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ── Book details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Title
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: AppColors.cream,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 3),

                // Author
                Text(
                  author,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),

                const SizedBox(height: 10),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    minHeight: 3,
                    backgroundColor: AppColors.cream.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(
                      status == 'completed'
                          ? AppColors.success
                          : AppColors.amber,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Footer row
                Row(
                  children: [
                    // Status chip
                    _StatusChip(status: status),
                    const Spacer(),
                    // Progress label
                    Text(
                      pctLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Options menu
          GestureDetector(
            onTap: () => _showOptions(context),
            child: Icon(
              Icons.more_vert_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ),

        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.midnight2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cream.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _optionItem(ctx, Icons.play_arrow_rounded,
                'Continue reading', AppColors.cream, () {
                  Navigator.pop(ctx);
                  final book = entry['books'] as Map<String, dynamic>? ?? {};
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => ReaderScreen(
                        bookTitle: book['title'] ?? 'Untitled',
                        fileUrl: book['file_url'] ?? '',
                        libraryEntryId: entry['id'],
                        initialPage: entry['reading_progress'] ?? 0,
                        totalPages: book['total_pages'] ?? 0,
                      ),
                    ),

                  );
                }),
            _optionItem(ctx, Icons.timer_outlined,
                'Set Pacer', AppColors.cream, () {
                  Navigator.pop(ctx);
                  // TODO: set pacer
                }),
            _optionItem(ctx, Icons.check_circle_outline_rounded,
                'Mark as completed', AppColors.success, () async {
                  Navigator.pop(ctx);
                  await _updateStatus(context, 'completed');
                }),
            _optionItem(ctx, Icons.bookmark_outline_rounded,
                'Move to wishlist', AppColors.cream, () async {
                  Navigator.pop(ctx);
                  await _updateStatus(context, 'wishlist');
                }),
            Divider(color: AppColors.cream.withOpacity(0.08)),
            _optionItem(ctx, Icons.delete_outline_rounded,
                'Remove from library', const Color(0xFFF09595), () async {
                  Navigator.pop(ctx);
                  await _deleteBook(context);
                }),
          ],
        ),
      ),
    );
  }

  Widget _optionItem(BuildContext context, IconData icon,
      String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(fontSize: 15, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await Supabase.instance.client
          .from('user_library')
          .update({'status': status})
          .eq('id', entry['id']);
      onDeleted(); // Refresh the list
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _deleteBook(BuildContext context) async {
    try {
      // Remove from user_library
      await Supabase.instance.client
          .from('user_library')
          .delete()
          .eq('id', entry['id']);
      onDeleted(); // Refresh the list
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }
}

// ── STATUS CHIP ────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'completed':
        bgColor = AppColors.success.withOpacity(0.12);
        textColor = AppColors.success;
        label = 'Completed';
        break;
      case 'wishlist':
        bgColor = AppColors.cream.withOpacity(0.06);
        textColor = AppColors.muted;
        label = 'Wishlist';
        break;
      default:
        bgColor = AppColors.amber.withOpacity(0.1);
        textColor = AppColors.amberLight;
        label = 'Reading';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}