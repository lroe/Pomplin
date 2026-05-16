import 'package:flutter/material.dart';
import 'roadmap.dart';
import 'chat.dart';
import 'services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  int _selectedNav = 0;
  bool _isLoading = true;
  List<dynamic> _goals = [];
  List<dynamic> _tasks = [];
  String _username = "User";

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bg        = Color(0xFF0D0D0D);
  static const Color _card      = Color(0xFF1C1C1E);
  static const Color _innerCard = Color(0xFF252528);
  static const Color _quoteCard = Color(0xFF1A1220);
  static const Color _divider   = Color(0xFF2A2A2A);
  static const Color _pink      = Color(0xFFD4607A);
  static const Color _grey      = Color(0xFF888888);
  static const Color _lightGrey = Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final goals = await _apiService.getGoals();
    final tasks = await _apiService.getTodaysTasks();
    setState(() {
      _goals = goals;
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildGoalsSection(),
                      const SizedBox(height: 28),
                      _buildTodaysMission(),
                      const SizedBox(height: 28),
                      _buildMascotAndQuote(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Morning, $_username.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'The obstacle is the way.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 17,
                fontStyle: FontStyle.italic,
                fontFamily: 'Georgia',
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, color: Colors.white54),
        ),
      ],
    );
  }

  // ── Goals section ──────────────────────────────────────────────────────────

  Widget _buildGoalsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ALL GOALS',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoadmapScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _innerCard,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _goals.isEmpty 
          ? const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No goals yet. Talk to Pomplin to start!", style: TextStyle(color: Colors.white54)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _goals.map((g) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 150,
                    child: _goalTile(g['title'], 0.5, g['goal_type'] ?? 'linear')
                  ),
                )).toList(),
              ),
            ),
      ],
    );
  }

  Widget _goalTile(String title, double progress, String subtitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFF3A3A3A),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 7),
          Text(subtitle, style: const TextStyle(color: _grey, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Today's Mission ────────────────────────────────────────────────────────

  Widget _buildTodaysMission() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TODAY'S MISSION",
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _tasks.isEmpty 
            ? const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No tasks for today. Ask Pomplin for a plan!", style: TextStyle(color: Colors.white54)),
              )
            : Column(
                children: _tasks.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final task = entry.value;
                  return Column(
                    children: [
                      _taskRow(task['title'], task['completed'] ?? false, () {
                        // Toggle task completion via API
                      }),
                      if (idx < _tasks.length - 1)
                        const Divider(height: 1, color: _divider, indent: 16, endIndent: 16),
                    ],
                  );
                }).toList(),
              ),
        ),
      ],
    );
  }

  Widget _taskRow(String label, bool done, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: done ? Colors.white : _grey,
                  width: 1.8,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 17)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
          ],
        ),
      ),
    );
  }

  // ── Mascot peeking over quote card ─────────────────────────────────────────

  Widget _buildMascotAndQuote() {
    const double renderHeight = 220.0;
    const double overlapIntoCard = 55.0;
    const double aboveCard = renderHeight - overlapIntoCard;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: aboveCard),
          child: _buildQuoteCard(),
        ),
        Positioned(
          top: 0,
          child: Image.asset(
            'assets/pomplin_quote.png',
            height: renderHeight,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
      decoration: BoxDecoration(
        color: _quoteCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Text(
              '\u201C\u201C',
              style: TextStyle(
                color: const Color(0xFF5A3570).withOpacity(0.7),
                fontSize: 46,
                height: 0.85,
                fontFamily: 'Georgia',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CODE OF THE DAY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _pink,
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Move fast and break things. Unless you are breaking stuff, you are not moving fast enough.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '— Mark Zuckerberg',
            textAlign: TextAlign.center,
            style: TextStyle(color: _lightGrey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pomplin says: This inspires me to innovate quickly!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _lightGrey,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.home_rounded,         label: 'Home'),
      _NavItem(icon: Icons.swap_horiz_rounded,   label: 'Roadmap'),
      _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
      _NavItem(icon: Icons.description_outlined, label: 'Community'),
    ];

    return Container(
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final active = _selectedNav == i;
                return GestureDetector(
                  onTap: () {
                    if (i == 1) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoadmapScreen()));
                    } else if (i == 2) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                    }
                    setState(() => _selectedNav = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          color: active ? Colors.white : const Color(0xFF666666),
                          size: 24,
                        ),
                        if (items[i].label.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            items[i].label,
                            style: TextStyle(
                              color: active ? Colors.white : const Color(0xFF666666),
                              fontSize: 11,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
