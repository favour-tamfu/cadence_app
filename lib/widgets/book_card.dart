import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../screens/reader/reader_screen.dart';

// ── BOOK CARD ─────────────────────────────────────────────────────────────────
class BookCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDeleted;

  const BookCard({super.key, required this.entry, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final book = entry['books'] as Map<String, dynamic>? ?? {};
    final title = book['title'] as String? ?? 'Untitled';
    final author = book['author'] as String? ?? 'Unknown';
    final totalPages = book['total_pages'] as int? ?? 0;
    final progress = entry['reading_progress'] as int? ?? 0;
    final status = entry['status'] as String? ?? 'reading';

    final pct = totalPages > 0 ? (progress / totalPages).clamp(0.0, 1.0) : 0.0;
    final pctLabel = totalPages > 0
        ? '${(pct * 100).round()}%'
        : progress > 0
            ? 'p.$progress'
            : '–';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Book cover placeholder
          Container(
            width: 48,
            height: 66,
            decoration: BoxDecoration(
              color: _coverColor(title),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'B',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 22,
                  color: Colors.white,
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

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: AppColors.cream,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  author == 'Unknown' ? 'PDF Document' : author,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),

                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    minHeight: 3,
                    backgroundColor: AppColors.cream.withValues(alpha:0.1),
                    valueColor: AlwaysStoppedAnimation(
                      status == 'completed' ? AppColors.success : AppColors.amber,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    StatusChip(status: status),
                    const Spacer(),
                    Text(
                      pctLabel,
                      style: const TextStyle(
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
            child: const Icon(Icons.more_vert_rounded, color: AppColors.muted, size: 20),
          ),
        ],
      ),
    );
  }

  Color _coverColor(String title) {
    final colors = [
      const Color(0xFF1A3A5C),
      const Color(0xFF2D4A22),
      const Color(0xFF4A1A2C),
      const Color(0xFF2A3A4A),
      const Color(0xFF3A2A4A),
      const Color(0xFF1A4A3A),
      const Color(0xFF4A3A1A),
    ];
    final index = title.isNotEmpty
        ? title.codeUnitAt(0) % colors.length
        : 0;
    return colors[index];
  }

  void _showOptions(BuildContext context) {
    final book = entry['books'] as Map<String, dynamic>? ?? {};
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
                color: AppColors.cream.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _optionItem(ctx, Icons.play_arrow_rounded,
                'Continue reading', AppColors.cream, () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ReaderScreen(
                  bookTitle: Uri.decodeComponent(
                    book['title'] ?? 'Untitled'.replaceAll('+', ' '),
                  ),
                  fileUrl: book['file_url'] ?? '',
                  fileType: book['file_type'] ?? 'pdf',
                  libraryEntryId: entry['id'],
                  bookId: book['id'] ?? '',
                  initialPage: entry['reading_progress'] ?? 0,
                  totalPages: book['total_pages'] ?? 0,
                )),
              ).then((_) => onDeleted()); // refresh list when reader closes
            }),
            _optionItem(ctx, Icons.timer_outlined,
                'Set Pacer', AppColors.cream, () {
              Navigator.pop(ctx);
              // TODO: set pacer (Sprint 4)
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
            Divider(color: AppColors.cream.withValues(alpha:0.08)),
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
            Text(label, style: TextStyle(fontSize: 15, color: color)),
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
      onDeleted();
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
      await Supabase.instance.client
          .from('user_library')
          .delete()
          .eq('id', entry['id']);
      onDeleted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }
}

// ── STATUS CHIP ───────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case 'completed':
        bgColor = AppColors.success.withValues(alpha:0.12);
        textColor = AppColors.success;
        label = 'Completed';
        break;
      case 'wishlist':
        bgColor = AppColors.cream.withValues(alpha:0.06);
        textColor = AppColors.muted;
        label = 'Wishlist';
        break;
      default:
        bgColor = AppColors.amber.withValues(alpha:0.1);
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
