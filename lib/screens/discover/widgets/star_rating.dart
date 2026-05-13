// ─────────────────────────────────────────────────────────────
//  lib/screens/discover/widgets/star_rating.dart
// ─────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

/// Read-only star display. Supports half-stars visually.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = (rating - i).clamp(0.0, 1.0);
        IconData icon;
        if (fill >= 0.75) {
          icon = Icons.star_rounded;
        } else if (fill >= 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: const Color(0xFFEF9F27));
      }),
    );
  }
}

/// Tappable stars for user input.
class InteractiveStarRating extends StatefulWidget {
  const InteractiveStarRating({
    super.key,
    required this.initialRating,
    required this.onRate,
  });

  final int initialRating;
  final ValueChanged<int> onRate;

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _hovered;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRating;
    _hovered = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = star <= (_hovered > 0 ? _hovered : _selected);
        return GestureDetector(
          onTap: () {
            setState(() => _selected = star);
            widget.onRate(star);
          },
          onTapDown: (_) => setState(() => _hovered = star),
          onTapCancel: () => setState(() => _hovered = _selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 32,
              color: filled
                  ? const Color(0xFFEF9F27)
                  : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.25),
            ),
          ),
        );
      }),
    );
  }
}