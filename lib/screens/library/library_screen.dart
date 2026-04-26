import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/book_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All', 'Reading', 'Completed', 'Uploads', 'Wishlist'
  ];

  String _sortBy = 'Recent';
  final List<String> _sortOptions = ['Recent', 'Title', 'Progress'];

  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Called by HomeScreen whenever the Library tab is switched to,
  /// so progress and page counts are always fresh.
  void refresh() => _loadBooks();

  // ── LOAD BOOKS FROM SUPABASE ───────────────────────────────────────────────
  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('user_library')
          .select('*, books(*)')
          .eq('user_id', userId)
          .order('started_at', ascending: false);

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'doc'],
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

      await _supabase.storage
          .from('books')
          .upload(filePath, File(file.path!));

      // Store the storage PATH (not a public URL) so the reader can
      // download via the authenticated Supabase SDK — required for
      // private buckets.
      final bookResponse = await _supabase
          .from('books')
          .insert({
        'title': _cleanTitle(file.name),
        'author': 'Unknown',
        'uploaded_by': userId,
        'file_url': filePath,          // storage path, e.g. users/.../books/xxx.pdf
        'file_type': file.extension?.toLowerCase() ?? 'pdf',
        'total_pages': 0,
        'is_public': false,
      })
          .select()
          .single();

      await _supabase.from('user_library').insert({
        'user_id': userId,
        'book_id': bookResponse['id'],
        'reading_progress': 0,
        'status': 'reading',
      });

      // Reset upload state BEFORE reloading so the button unlocks immediately
      setState(() => _isUploading = false);
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

  String _cleanTitle(String fileName) {
    return Uri.decodeComponent(fileName)
        .replaceAll('.pdf', '')
        .replaceAll('.epub', '')
        .replaceAll('.doc', '')
        .replaceAll('+', ' ')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── FILTER + SEARCH + SORT BOOKS ──────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredBooks {
    final query = _searchController.text.trim().toLowerCase();
    List<Map<String, dynamic>> result = _books;

    // Apply filter tab
    if (_selectedFilter != 'All') {
      result = result.where((entry) {
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

    // Apply search
    if (query.isNotEmpty) {
      result = result.where((entry) {
        final book = entry['books'] as Map<String, dynamic>? ?? {};
        final title  = (book['title']  as String? ?? '').toLowerCase();
        final author = (book['author'] as String? ?? '').toLowerCase();
        return title.contains(query) || author.contains(query);
      }).toList();
    }

    // Apply sort
    switch (_sortBy) {
      case 'Title':
        result.sort((a, b) {
          final titleA = (a['books']?['title'] as String? ?? '').toLowerCase();
          final titleB = (b['books']?['title'] as String? ?? '').toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
      case 'Progress':
        result.sort((a, b) {
          final progA = a['reading_progress'] as int? ?? 0;
          final progB = b['reading_progress'] as int? ?? 0;
          return progB.compareTo(progA);
        });
        break;
      default: // Recent — already ordered by started_at from Supabase
        break;
    }

    return result;
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
                  GestureDetector(
                    onTap: _isUploading ? null : _uploadBook,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
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
                          : const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: AppColors.cream),
                decoration: InputDecoration(
                  hintText: 'Search by title or author…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.muted, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.muted, size: 18),
                  )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: AppColors.cream.withValues(alpha:0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.cream.withValues(alpha:0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.cream.withValues(alpha:0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.amber),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

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
                            : AppColors.cream.withValues(alpha:0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? AppColors.amber
                              : AppColors.cream.withValues(alpha:0.12),
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

            // ── Sort row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Row(
                children: [
                  Text(
                    '${_filteredBooks.length} book${_filteredBooks.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const Spacer(),
                  const Text('Sort: ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: AppColors.midnight2,
                    style: const TextStyle(fontSize: 12, color: AppColors.amberLight),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.expand_more_rounded,
                        size: 16, color: AppColors.amberLight),
                    items: _sortOptions.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sortBy = val);
                    },
                  ),
                ],
              ),
            ),

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
                    return BookCard(
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
    final isSearching = _searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.collections_bookmark_outlined,
              size: 52,
              color: AppColors.muted.withValues(alpha:0.4),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching
                  ? 'No results found.'
                  : isFiltered
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
              isSearching
                  ? 'Try a different title or author name.'
                  : isFiltered
                  ? 'Change the filter or add a new book.'
                  : 'Tap the + button to upload your first PDF.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            if (!isFiltered && !isSearching) ...[
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
