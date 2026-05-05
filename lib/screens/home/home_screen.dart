import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../library/library_screen.dart';
import '../reader/reader_screen.dart';
import '../auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/pacer_calculator.dart';
import '../dashboard/dashboard_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _homeRefreshKey = 0;
  final _libraryKey = GlobalKey<LibraryScreenState>();

  void _onTabTap(int i) {
    if (i == 0) setState(() => _homeRefreshKey++);
    if (i == 1) _libraryKey.currentState?.refresh();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _HomeContent(key: ValueKey(_homeRefreshKey)),
            LibraryScreen(key: _libraryKey),
            const _DiscoverPlaceholder(),
            const _ProfilePlaceholder(),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: _onTabTap,
        ),
      ),
    );
  }
}

// ── BOTTOM NAV ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.midnight,
        border: Border(
          top: BorderSide(color: AppColors.cream.withValues(alpha:0.07), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _navItem(1, Icons.collections_bookmark, Icons.collections_bookmark_outlined, 'Library'),
              _navItem(2, Icons.explore_rounded, Icons.explore_outlined, 'Discover'),
              _navItem(3, Icons.person_rounded, Icons.person_outlined, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData active, IconData inactive, String label) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? active : inactive,
              color: isActive ? AppColors.amberLight : AppColors.muted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.amberLight : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── HOME CONTENT ──────────────────────────────────────────────────────────────
class _HomeContent extends StatefulWidget {
  const _HomeContent({super.key});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final _pacerKey = GlobalKey<_PacerCardState>();

  String _getFirstName() {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    if (fullName != null && fullName.isNotEmpty) {
      return fullName.split(' ').first;
    }
    final email = user?.email ?? '';
    return email.split('@').first;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [

          // ── App bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()},',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getFirstName(),
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 24,
                            color: AppColors.cream,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showProfileMenu(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.cream.withValues(alpha:0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.cream.withValues(alpha:0.12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getFirstName().isNotEmpty
                              ? _getFirstName()[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.amberLight,
                            fontFamily: 'PlayfairDisplay',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Continue reading (most important — moved to top)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _SectionLabel(label: 'Continue reading'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ContinueReadingCard(
                onReaderClosed: () => _pacerKey.currentState?.reload(),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Streak hero
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _StreakHero(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Pacer card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PacerCard(key: _pacerKey),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Up next (hidden until real data is wired in Sprint 3)
          const SliverToBoxAdapter(
            child: SizedBox.shrink(),
          ),

          // ── Discover teaser
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SectionLabel(
                label: 'From the community',
                action: 'Browse all',
                onAction: () {},
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: _DiscoverTeaser()),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final name = user?.userMetadata?['full_name'] as String? ?? email.split('@').first;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.midnight2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ProfileMenuSheet(name: name, email: email),
    );
  }
}

// ── STREAK HERO ───────────────────────────────────────────────────────────────
class _StreakHero extends StatelessWidget {
  final VoidCallback? onTap;
  const _StreakHero({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cream.withValues(alpha:0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: AppColors.amberLight, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '0 day streak',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    color: AppColors.cream,
                  ),
                ),
                Text(
                  'Read today to start your streak',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(7, (i) {
              final isToday = i == 6;
              return Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? AppColors.amber.withValues(alpha:0.4)
                      : AppColors.cream.withValues(alpha:0.1),
                ),
              );
            }),
          ),
        ],
      ),
    ));
  }
}

// ── PACER CARD ────────────────────────────────────────────────────────────────
class _PacerCard extends StatefulWidget {
  const _PacerCard({super.key});

  @override
  State<_PacerCard> createState() => _PacerCardState();
}

class _PacerCardState extends State<_PacerCard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _activeEntry;
  bool _isLoading = true;
  int _pagesReadToday = 0;

  @override
  void initState() {
    super.initState();
    _loadActivePacer();
  }

  void reload() => _loadActivePacer();

  Future<void> _loadActivePacer() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Find the book with an active Pacer — has a target date set
      final response = await _supabase
          .from('user_library')
          .select('*, books(*)')
          .eq('user_id', userId)
          .eq('status', 'reading')
          .not('pacer_target_date', 'is', null)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final entryId = response['id'] as String;
        final progress = response['reading_progress'] as int? ?? 0;
        await _loadDailyProgress(entryId, progress);
      }

      setState(() {
        _activeEntry = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Tracks how many pages the user has read today by storing a per-day
  // baseline in SharedPreferences. Resets automatically at midnight.
  Future<void> _loadDailyProgress(String entryId, int currentProgress) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final storedDate = prefs.getString('pacer_date_$entryId');

    if (storedDate != todayStr) {
      // New day — set today's baseline to where the user is right now
      await prefs.setString('pacer_date_$entryId', todayStr);
      await prefs.setInt('pacer_start_$entryId', currentProgress);
      _pagesReadToday = 0;
    } else {
      final startPage = prefs.getInt('pacer_start_$entryId') ?? currentProgress;
      _pagesReadToday = (currentProgress - startPage).clamp(0, currentProgress);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.15)),
        ),
        child: const SizedBox(
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.amber, strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // No active Pacer — show empty state
    if (_activeEntry == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "TODAY'S PACER GOAL",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.amber,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.amberLight, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No Pacer set yet — go to Library, long press a book, and tap "Set Pacer".',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.cream.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Active Pacer — show real data
    final book = _activeEntry!['books'] as Map<String, dynamic>? ?? {};
    final title = book['title'] as String? ?? 'Untitled';
    final totalPages = book['total_pages'] as int? ?? 0;
    final progress = _activeEntry!['reading_progress'] as int? ?? 0;
    final targetDateStr = _activeEntry!['pacer_target_date'] as String?;
    final targetDate = targetDateStr != null
        ? DateTime.parse(targetDateStr)
        : DateTime.now().add(const Duration(days: 7));

    // Recalculate live goal in case they missed days
    final liveGoal = PacerCalculator.dailyGoal(
      totalPages: totalPages,
      currentPage: progress,
      targetDate: targetDate,
    );
    // Pages still needed today = daily goal minus what's already been read today
    final remaining = (liveGoal - _pagesReadToday).clamp(0, liveGoal);

    final daysLeft = PacerCalculator.daysRemaining(targetDate);
    final pct = PacerCalculator.progressPercent(
      totalPages: totalPages,
      currentPage: progress,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Eyebrow
          const Text(
            "TODAY'S PACER GOAL",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.amber,
              letterSpacing: 1.8,
            ),
          ),

          const SizedBox(height: 10),

          // Pages remaining today
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$remaining',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 52,
                  color: AppColors.cream,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  remaining == 0 ? 'goal met today!' : 'pages left today',
                  style: TextStyle(
                    fontSize: 16,
                    color: remaining == 0
                        ? AppColors.amberLight
                        : AppColors.cream.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Book title + today's reading progress
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (_pagesReadToday > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '$_pagesReadToday of $liveGoal pages read today',
                style: const TextStyle(fontSize: 11, color: AppColors.amberLight),
              ),
            ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: AppColors.cream.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),

          const SizedBox(height: 8),

          // Meta row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(pct * 100).round()}% complete',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                daysLeft == 0
                    ? 'Due today!'
                    : '$daysLeft days left',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.amberLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

// ── CONTINUE READING ──────────────────────────────────────────────────────────
class _ContinueReadingCard extends StatefulWidget {
  final VoidCallback? onReaderClosed;
  const _ContinueReadingCard({this.onReaderClosed});

  @override
  State<_ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<_ContinueReadingCard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _entry;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final prefs = await SharedPreferences.getInstance();
      final lastEntryId = prefs.getString('last_read_entry');

      Map<String, dynamic>? response;

      // Prefer the book the user most recently opened in the reader
      if (lastEntryId != null) {
        response = await _supabase
            .from('user_library')
            .select('*, books(*)')
            .eq('user_id', userId)
            .eq('id', lastEntryId)
            .eq('status', 'reading')
            .maybeSingle();
      }

      // Fall back to most recently added reading book
      response ??= await _supabase
          .from('user_library')
          .select('*, books(*)')
          .eq('user_id', userId)
          .eq('status', 'reading')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // TODO: Pin feature — let users pin any book to always appear here,
      // regardless of reading recency. A pin icon in the book card's options
      // menu would store `pinned: true` in user_library; query for it first
      // before falling back to last-read or started_at ordering.

      if (mounted) setState(() { _entry = response; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.cream.withValues(alpha:0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.amber, strokeWidth: 2),
        ),
      );
    }
    if (_entry == null) return _buildEmpty();
    return _buildCard(context);
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 64,
            decoration: BoxDecoration(
              color: AppColors.midnight3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
            ),
            child: Icon(Icons.menu_book_rounded,
                color: AppColors.muted.withValues(alpha:0.5), size: 22),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your library is quiet.',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 17,
                    color: AppColors.cream,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Let's change that. Upload your first book.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final book = _entry!['books'] as Map<String, dynamic>? ?? {};
    final title = book['title'] as String? ?? 'Untitled';
    final author = book['author'] as String? ?? 'Unknown';
    final totalPages = book['total_pages'] as int? ?? 0;
    final progress = _entry!['reading_progress'] as int? ?? 0;
    final pct = totalPages > 0 ? (progress / totalPages).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // Cover
          Container(
            width: 52, height: 72,
            decoration: BoxDecoration(
              color: AppColors.midnight3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
            ),
            child: Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'B',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 26,
                  color: AppColors.amberLight,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

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
                    fontSize: 17,
                    color: AppColors.cream,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(author,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    minHeight: 3,
                    backgroundColor: AppColors.cream.withValues(alpha:0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.amber),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      totalPages > 0
                          ? 'Page $progress of $totalPages'
                          : 'Page $progress',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const Spacer(),
                    Text(
                      '${(pct * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.amberLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Read button
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReaderScreen(
                bookTitle: title,
                fileUrl: book['file_url'] ?? '',
                fileType: book['file_type'] ?? 'pdf',
                libraryEntryId: _entry!['id'],
                bookId: book['id'] ?? '',
                initialPage: progress,
                totalPages: totalPages,
              )),
            ).then((_) { _load(); widget.onReaderClosed?.call(); }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── UP NEXT SHELF ─────────────────────────────────────────────────────────────
class _UpNextShelf extends StatefulWidget {
  const _UpNextShelf();

  @override
  State<_UpNextShelf> createState() => _UpNextShelfState();
}

class _UpNextShelfState extends State<_UpNextShelf> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('user_library')
          .select('*, books(*)')
          .eq('user_id', userId)
          .eq('status', 'wishlist')
          .order('created_at', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() {
          _books = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: 3,
          itemBuilder: (_, __) => Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.midnight3,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (_books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.cream.withValues(alpha:0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
          ),
          child: Row(
            children: [
              Icon(Icons.bookmark_outline_rounded,
                  color: AppColors.muted.withValues(alpha:0.5), size: 20),
              const SizedBox(width: 12),
              const Text(
                'No wishlist books yet.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _books.length,
        itemBuilder: (ctx, i) {
          final entry = _books[i];
          final book = entry['books'] as Map<String, dynamic>? ?? {};
          final title = book['title'] as String? ?? 'Untitled';
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReaderScreen(
                bookTitle: title,
                fileUrl: book['file_url'] ?? '',
                fileType: book['file_type'] ?? 'pdf',
                libraryEntryId: entry['id'],
                bookId: book['id'] ?? '',
                initialPage: entry['reading_progress'] ?? 0,
                totalPages: book['total_pages'] ?? 0,
              )),
            ),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.midnight3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cream.withValues(alpha:0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        title.isNotEmpty ? title[0].toUpperCase() : 'B',
                        style: const TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 36,
                          color: AppColors.amberLight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.cream,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── DISCOVER TEASER ───────────────────────────────────────────────────────────
class _DiscoverTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha:0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withValues(alpha:0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.explore_outlined,
                color: AppColors.amberLight, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community books',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: AppColors.cream,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Trending this week — see what the community is reading.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.muted, size: 14),
        ],
      ),
    );
  }
}

// ── SECTION LABEL ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? action;
  final VoidCallback? onAction;
  const _SectionLabel({required this.label, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
            letterSpacing: 1.4,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.amberLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// ── PROFILE MENU SHEET ────────────────────────────────────────────────────────
class _ProfileMenuSheet extends StatelessWidget {
  final String name;
  final String email;
  const _ProfileMenuSheet({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
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
          const SizedBox(height: 24),

          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha:0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.amber.withValues(alpha:0.25)),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 28,
                  color: AppColors.amberLight,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            name,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),

          const SizedBox(height: 24),
          Divider(color: AppColors.cream.withValues(alpha:0.08), thickness: 0.5),

          _menuItem(context, Icons.workspace_premium_outlined,
              'Upgrade to Premium', AppColors.amberLight, () {}),
          _menuItem(context, Icons.bar_chart_rounded,
              'Reading stats', AppColors.cream, () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              }),
          _menuItem(context, Icons.settings_outlined,
              'Settings', AppColors.cream, () {}),
          _menuItem(context, Icons.help_outline_rounded,
              'Help & feedback', AppColors.cream, () {}),

          Divider(color: AppColors.cream.withValues(alpha:0.08), thickness: 0.5),

          _menuItem(context, Icons.logout_rounded,
              'Log out', const Color(0xFFF09595), () async {
                await Supabase.instance.client.auth.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('seen_onboarding', false);
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              }),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
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
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (label != 'Log out')
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.muted, size: 13),
          ],
        ),
      ),
    );
  }
}

// ── PLACEHOLDER SCREENS ───────────────────────────────────────────────────────
class _DiscoverPlaceholder extends StatelessWidget {
  const _DiscoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.midnight,
      body: Center(
        child: Text('Discover — coming soon',
            style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.midnight,
      body: Center(
        child: Text('Profile — coming soon',
            style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
