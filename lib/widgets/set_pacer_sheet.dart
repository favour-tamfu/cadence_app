import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/pacer_calculator.dart';

class SetPacerSheet extends StatefulWidget {
  /// The library entry id — we update user_library directly
  final String libraryEntryId;

  /// Current reading progress so we can show a live preview
  final int currentPage;
  final int totalPages;
  final String bookTitle;

  /// Called after the Pacer is saved so the caller can refresh
  final VoidCallback onSaved;

  const SetPacerSheet({
    super.key,
    required this.libraryEntryId,
    required this.currentPage,
    required this.totalPages,
    required this.bookTitle,
    required this.onSaved,
  });

  @override
  State<SetPacerSheet> createState() => _SetPacerSheetState();
}

class _SetPacerSheetState extends State<SetPacerSheet> {
  final _supabase = Supabase.instance.client;

  // Selected finish date — defaults to 14 days from today
  DateTime _targetDate = DateTime.now().add(const Duration(days: 14));

  bool _isSaving = false;

  // ── Live preview values ───────────────────────────────────────────────────
  int get _pagesLeft => (widget.totalPages - widget.currentPage)
      .clamp(0, widget.totalPages);

  int get _daysLeft => PacerCalculator.daysRemaining(_targetDate);

  int get _dailyGoal => PacerCalculator.dailyGoal(
    totalPages: widget.totalPages,
    currentPage: widget.currentPage,
    targetDate: _targetDate,
  );

  // ── Save Pacer to Supabase ────────────────────────────────────────────────
  Future<void> _savePacer() async {
    setState(() => _isSaving = true);

    try {
      await _supabase.from('user_library').update({
        'pacer_target_date': _targetDate.toIso8601String(),
        'daily_page_goal': _dailyGoal,
      }).eq('id', widget.libraryEntryId);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.midnight3,
          ),
        );
      }
    }
  }

  // ── Remove Pacer ──────────────────────────────────────────────────────────
  Future<void> _removePacer() async {
    try {
      await _supabase.from('user_library').update({
        'pacer_target_date': null,
        'daily_page_goal': 0,
      }).eq('id', widget.libraryEntryId);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.midnight2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Handle
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          )),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Set your Pacer',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 24,
              color: AppColors.cream,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            widget.bookTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),

          const SizedBox(height: 24),

          // ── Live preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                // Daily goal — the big number
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_dailyGoal',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 56,
                        color: AppColors.cream,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'pages/day',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Three info chips
                Row(
                  children: [
                    _infoChip(
                      'Finish date',
                      PacerCalculator.targetLabel(_targetDate),
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      'Days left',
                      _daysLeft == 0 ? 'Today!' : '$_daysLeft',
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      'Pages left',
                      '$_pagesLeft',
                    ),
                  ],
                ),

                // Warning if goal is too high
                if (_dailyGoal > 80) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.amberLight.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'That\'s a high daily goal. Consider a later date.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.amberLight.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Date picker label
          const Text(
            'FINISH DATE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
              color: AppColors.muted,
            ),
          ),

          const SizedBox(height: 12),

          // ── Date picker row — quick options + custom
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _dateChip('1 week',  DateTime.now().add(const Duration(days: 7))),
                const SizedBox(width: 8),
                _dateChip('2 weeks', DateTime.now().add(const Duration(days: 14))),
                const SizedBox(width: 8),
                _dateChip('1 month', DateTime.now().add(const Duration(days: 30))),
                const SizedBox(width: 8),
                _dateChip('3 months',DateTime.now().add(const Duration(days: 90))),
                const SizedBox(width: 8),
                // Custom date picker
                GestureDetector(
                  onTap: _pickCustomDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cream.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppColors.muted),
                        SizedBox(width: 6),
                        Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving || _dailyGoal <= 0 ? null : _savePacer,
              child: _isSaving
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white,
                ),
              )
                  : const Text(
                'Set Pacer',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Remove button (subtle)
          Center(
            child: GestureDetector(
              onTap: _removePacer,
              child: const Text(
                'Remove Pacer',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.muted,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── Pick a custom date ─────────────────────────────────────────────────────
  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.amber,
            surface: AppColors.midnight2,
            onSurface: AppColors.cream,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) setState(() => _targetDate = picked);
  }

  // ── Quick date chip ───────────────────────────────────────────────────────
  Widget _dateChip(String label, DateTime date) {
    final isSelected = _targetDate.year == date.year &&
        _targetDate.month == date.month &&
        _targetDate.day == date.day;

    return GestureDetector(
      onTap: () => setState(() => _targetDate = date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.amber
              : AppColors.cream.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.amber
                : AppColors.cream.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  // ── Info chip (inside preview card) ──────────────────────────────────────
  Widget _infoChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cream.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 18,
                color: AppColors.amberLight,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}