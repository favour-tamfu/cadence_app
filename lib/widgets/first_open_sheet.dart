import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/companion.dart';
import '../services/companion_session_manager.dart';

// ─────────────────────────────────────────────────────────────
//  FirstOpenSheet
//  Shown once when a user opens a book with no session yet.
//  Lets them pick companion, verbosity, and reading goal.
// ─────────────────────────────────────────────────────────────
class FirstOpenSheet extends StatefulWidget {
  const FirstOpenSheet({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    final manager = context.read<CompanionSessionManager>();
    if (manager.session == null || !manager.session!.isNew) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FirstOpenSheet(),
    );
  }

  @override
  State<FirstOpenSheet> createState() => _FirstOpenSheetState();
}

class _FirstOpenSheetState extends State<FirstOpenSheet> {
  CompanionType _selectedType = CompanionType.echo;
  Verbosity _verbosity = Verbosity.moderate;
  final _goalController = TextEditingController();
  int _step = 0;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.midnight2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: _step == 0 ? _buildStep0() : _buildStep1(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: Pick a companion ──────────────────────────────

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your reading companion',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.cream,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'You can change this any time in settings.',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        ...CompanionType.values.map(
          (type) => _CompanionCard(
            type: type,
            selected: _selectedType == type,
            onTap: () => setState(() => _selectedType = type),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _skip,
                child: const Text('Skip for now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _selectedType.primaryColor,
                  minimumSize: const Size(0, 52),
                ),
                onPressed: () => setState(() => _step = 1),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 1: Verbosity + reading goal ─────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _step = 0),
          child: const Row(
            children: [
              Icon(Icons.arrow_back_ios_rounded,
                  size: 16, color: AppColors.amber),
              SizedBox(width: 4),
              Text('Back', style: TextStyle(color: AppColors.amber)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'How much detail do you like?',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...Verbosity.values.map(
          (v) => _VerbosityTile(
            verbosity: v,
            selected: _verbosity == v,
            companion: _selectedType,
            onTap: () => setState(() => _verbosity = v),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "What's your goal with this book?",
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _goalController,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'e.g. "Understand Stoic philosophy" or leave blank',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _selectedType.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _confirm,
            child: Text('Start reading with ${_selectedType.displayName}'),
          ),
        ),
      ],
    );
  }

  void _confirm() {
    final config = CompanionConfig.defaultFor(_selectedType).copyWith(
      verbosity: _verbosity,
    );
    context.read<CompanionSessionManager>().applyFirstOpenConfig(
          config: config,
          readerGoal: _goalController.text.trim(),
        );
    Navigator.of(context).pop();
  }

  void _skip() => Navigator.of(context).pop();
}

// ─────────────────────────────────────────────────────────────
//  Companion card
// ─────────────────────────────────────────────────────────────
class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final CompanionType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? type.primaryColor.withValues(alpha: 0.15)
              : AppColors.midnight3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? type.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: type.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  type.displayName[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        type.displayName,
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: type.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.tagline,
                          style: TextStyle(
                            fontSize: 11,
                            color: type.lightColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: type.suitedGenres
                        .take(3)
                        .map(
                          (g) => Chip(
                            label: Text(
                              g,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.cream,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            backgroundColor:
                                type.primaryColor.withValues(alpha: 0.15),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: type.primaryColor),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Verbosity tile
// ─────────────────────────────────────────────────────────────
class _VerbosityTile extends StatelessWidget {
  const _VerbosityTile({
    required this.verbosity,
    required this.selected,
    required this.companion,
    required this.onTap,
  });

  final Verbosity verbosity;
  final bool selected;
  final CompanionType companion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? companion.primaryColor.withValues(alpha: 0.15)
              : AppColors.midnight3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? companion.primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verbosity.label,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    verbosity.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.radio_button_checked,
                  color: companion.primaryColor, size: 20)
            else
              Icon(Icons.radio_button_unchecked,
                  color: AppColors.muted.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
