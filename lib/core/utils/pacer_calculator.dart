/// Pure Pacer logic — no Flutter dependencies.
/// Every calculation in the app goes through this class.
class PacerCalculator {

  /// How many pages the user needs to read today.
  ///
  /// [totalPages]   — total pages in the book
  /// [currentPage]  — page the user is currently on
  /// [targetDate]   — the date they want to finish by
  ///
  /// Returns 0 if the book is already finished.
  /// Returns totalPages - currentPage if the deadline is today or past.
  static int dailyGoal({
    required int totalPages,
    required int currentPage,
    required DateTime targetDate,
  }) {
    // Already finished
    if (currentPage >= totalPages && totalPages > 0) return 0;

    final pagesLeft = totalPages - currentPage;
    if (pagesLeft <= 0) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      targetDate.year, targetDate.month, targetDate.day,
    );

    final daysLeft = target.difference(todayDate).inDays;

    // Deadline is today or already passed — finish it today
    if (daysLeft <= 0) return pagesLeft;

    // Round up so the user always finishes on or before the target date
    return (pagesLeft / daysLeft).ceil().clamp(1, pagesLeft);
  }

  /// How many days remain until the target date (including today).
  static int daysRemaining(DateTime targetDate) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      targetDate.year, targetDate.month, targetDate.day,
    );
    return target.difference(todayDate).inDays.clamp(0, 9999);
  }

  /// Percentage of the book completed (0.0 to 1.0).
  static double progressPercent({
    required int totalPages,
    required int currentPage,
  }) {
    if (totalPages <= 0) return 0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  /// Whether the user is on track — they've read at least
  /// as many pages today as their daily goal requires.
  static bool isOnTrack({
    required int pagesReadToday,
    required int dailyGoal,
  }) {
    if (dailyGoal <= 0) return true;
    return pagesReadToday >= dailyGoal;
  }

  /// A human-readable label for the finish date.
  static String targetLabel(DateTime targetDate) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      targetDate.year, targetDate.month, targetDate.day,
    );
    final days = target.difference(todayDate).inDays;

    if (days < 0)  return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days < 7)  return 'In $days days';

    // Format as "Apr 15"
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[targetDate.month - 1]} ${targetDate.day}';
  }
}