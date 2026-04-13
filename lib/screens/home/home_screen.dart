import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../library/library_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _HomeContent(),
    LibraryScreen(),
    _DiscoverPlaceholder(),
    _ProfilePlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
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
          top: BorderSide(color: AppColors.cream.withOpacity(0.07), width: 0.5),
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
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  // Get the user's first name from Supabase auth metadata
  String _getFirstName() {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    if (fullName != null && fullName.isNotEmpty) {
      return fullName.split(' ').first;
    }
    // Fallback to email prefix
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
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: CustomScrollView(
        slivers: [

          // ── App bar with greeting + profile icon
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
                          style: TextStyle(
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
                            fontSize: 28,
                            color: AppColors.cream,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Profile / menu button
                  GestureDetector(
                    onTap: () => _showProfileMenu(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.cream.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.cream.withOpacity(0.12),
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

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Streak hero bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _StreakHero(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Pacer card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _PacerCard(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Continue reading
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SectionLabel(label: 'Continue reading'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ContinueReadingCard(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Up next shelf (horizontal scroll)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SectionLabel(
                label: 'Up next',
                action: 'See library',
                onAction: () {},
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: _UpNextShelf()),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

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
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cream.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cream.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // Flame icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: AppColors.amberLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '0 day streak',
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 18,
                        color: AppColors.cream,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Read today to start your streak',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          // Week dots
          Row(
            children: List.generate(7, (i) {
              final isToday = i == 6;
              return Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? AppColors.amber.withOpacity(0.4)
                      : AppColors.cream.withOpacity(0.1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── PACER CARD ────────────────────────────────────────────────────────────────
class _PacerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S PACER GOAL",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.amber,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          // Empty state — no book with Pacer set yet
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: AppColors.amberLight, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No Pacer set yet — add a book to your library and set a finish date.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.cream.withOpacity(0.65),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Upload a book →',
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

// ── CONTINUE READING ──────────────────────────────────────────────────────────
class _ContinueReadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Empty state — no books yet
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Book icon placeholder
          Container(
            width: 48, height: 64,
            decoration: BoxDecoration(
              color: AppColors.midnight3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cream.withOpacity(0.08)),
            ),
            child: Icon(Icons.menu_book_rounded,
                color: AppColors.muted.withOpacity(0.5), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your library is quiet.',
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 17,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
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
}

// ── UP NEXT SHELF ─────────────────────────────────────────────────────────────
class _UpNextShelf extends StatelessWidget {
  final List<Map<String, dynamic>> _placeholders = const [
    {'color': Color(0xFF1C2E42), 'label': 'Add a book'},
    {'color': Color(0xFF142234), 'label': 'to your'},
    {'color': Color(0xFF2C3E52), 'label': 'library'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _placeholders.length,
        itemBuilder: (ctx, i) {
          final item = _placeholders[i];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: item['color'],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cream.withOpacity(0.06)),
            ),
            child: Center(
              child: Text(
                item['label'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
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
        color: AppColors.cream.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cream.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.explore_outlined,
                color: AppColors.amberLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community books',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Discover what others are reading and publishing.',
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
          style: TextStyle(
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
              style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.cream.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar + name
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.amber.withOpacity(0.25),
              ),
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
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),

          const SizedBox(height: 24),
          Divider(color: AppColors.cream.withOpacity(0.08), thickness: 0.5),

          // Menu items
          _menuItem(context, Icons.workspace_premium_outlined,
              'Upgrade to Premium', AppColors.amberLight, () {}),
          _menuItem(context, Icons.bar_chart_rounded,
              'Reading stats', AppColors.cream, () {}),
          _menuItem(context, Icons.settings_outlined,
              'Settings', AppColors.cream, () {}),
          _menuItem(context, Icons.help_outline_rounded,
              'Help & feedback', AppColors.cream, () {}),

          Divider(color: AppColors.cream.withOpacity(0.08), thickness: 0.5),

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
              Icon(Icons.arrow_forward_ios_rounded,
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
    return Scaffold(
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
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Center(
        child: Text('Profile — coming soon',
            style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}