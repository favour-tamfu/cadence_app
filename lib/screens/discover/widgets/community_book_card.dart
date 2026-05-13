// ─────────────────────────────────────────────────────────────
//  lib/screens/discover/widgets/community_book_card.dart
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../models/community_book.dart';
import 'star_rating.dart';

class CommunityBookCard extends StatelessWidget {
  const CommunityBookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.compact = false,
    this.showRating = false,
  });

  final CommunityBook book;
  final VoidCallback onTap;
  final bool compact;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      // Horizontal list card — 130×190
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: book.coverUrl != null
                    ? Image.network(
                  book.coverUrl!,
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _PlaceholderCover(title: book.title, size: 130),
                )
                    : _PlaceholderCover(title: book.title, size: 130),
              ),
              const SizedBox(height: 6),
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              if (showRating && book.ratingCount > 0)
                StarRating(rating: book.averageRating, size: 12),
            ],
          ),
        ),
      );
    }

    // Grid card
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: book.coverUrl != null
                  ? Image.network(
                book.coverUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _PlaceholderCover(
                    title: book.title, size: double.infinity),
              )
                  : _PlaceholderCover(
                  title: book.title, size: double.infinity),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
          if (book.ratingCount > 0)
            Row(
              children: [
                StarRating(rating: book.averageRating, size: 11),
                const SizedBox(width: 3),
                Text(
                  book.averageRating.toStringAsFixed(1),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.title, required this.size});
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      color: theme.colorScheme.surfaceVariant,
      child: Center(
        child: Text(
          title.length > 2 ? title.substring(0, 2).toUpperCase() : title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}