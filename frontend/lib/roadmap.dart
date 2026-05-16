import 'package:flutter/material.dart';
import 'homepage.dart';
import 'chat.dart';
import 'services/api_service.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum PhaseStatus { completed, active, locked }

class RoadmapTask {
  final String title;
  final bool done;
  final String? mascotAsset; 
  RoadmapTask({required this.title, required this.done, this.mascotAsset});
}

class RoadmapPhase {
  final String label; 
  final PhaseStatus status;
  final List<RoadmapTask> tasks;
  final String? lockedSubtitle;
  RoadmapPhase({
    required this.label,
    required this.status,
    required this.tasks,
    this.lockedSubtitle,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RoadmapScreen extends StatefulWidget {
  final Map<String, dynamic>? draftGoal;
  final String? draftTitle;
  const RoadmapScreen({super.key, this.draftGoal, this.draftTitle});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  final ApiService _apiService = ApiService();
  int _selectedGoalIdx = 0;
  int _selectedNav = 1; 
  bool _isLoading = true;
  List<dynamic> _goals = [];
  List<RoadmapPhase> _phases = [];
  bool _isPreviewMode = false;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _divider = Color(0xFF2A2A2A);
  static const Color _grey = Color(0xFF888888);
  static const Color _yellowGreen = Color(0xFFBDD446);
  static const Color _green = Color(0xFF8BC34A);

  @override
  void initState() {
    super.initState();
    if (widget.draftGoal != null) {
      _setupPreview();
    } else {
      _fetchGoals();
    }
  }

  void _setupPreview() {
    setState(() {
      _isPreviewMode = true;
      _isLoading = false;
      _goals = [{
        'title': widget.draftTitle ?? 'Draft Plan',
        'roadmap': widget.draftGoal,
      }];
      _parseRoadmap(_goals[0]);
    });
  }

  Future<void> _fetchGoals() async {
    setState(() => _isLoading = true);
    final goals = await _apiService.getGoals();
    setState(() {
      _goals = goals;
      if (_goals.isNotEmpty) {
        _parseRoadmap(_goals[_selectedGoalIdx]);
      }
      _isLoading = false;
    });
  }

  void _parseRoadmap(Map<String, dynamic> goal) {
    final roadmap = goal['roadmap'];
    if (roadmap == null || (roadmap['phases'] == null && roadmap['nodes'] == null)) {
      _phases = [];
      return;
    }

    if (roadmap['phases'] != null) {
      final List<dynamic> phasesJson = roadmap['phases'];
      _phases = phasesJson.map((p) {
        final List<dynamic> tasksJson = p['tasks'] ?? [];
        return RoadmapPhase(
          label: p['label'] ?? p['title'] ?? "Phase",
          status: _determineStatus(p['status']),
          tasks: tasksJson.map((t) => RoadmapTask(
            title: t['title'] ?? "",
            done: t['done'] ?? false,
            mascotAsset: t['done'] == true ? 'assets/pomplin_completed.png' : 'assets/pomplin_active.png',
          )).toList(),
        );
      }).toList();
    } else if (roadmap['nodes'] != null) {
       final List<dynamic> nodesJson = roadmap['nodes'];
       _phases = [
         RoadmapPhase(
           label: "RECURRING HABITS",
           status: PhaseStatus.active,
           tasks: nodesJson.map((n) => RoadmapTask(
             title: n['title'] ?? "",
             done: false,
             mascotAsset: 'assets/pomplin_active.png',
           )).toList(),
         )
       ];
    }
  }

  PhaseStatus _determineStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed': return PhaseStatus.completed;
      case 'active': return PhaseStatus.active;
      default: return PhaseStatus.locked;
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
              child: _goals.isEmpty 
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/pomplin_reading.png', height: 200),
                      const SizedBox(height: 16),
                      const Text("No roadmaps yet. Create a goal in Chat!", style: TextStyle(color: Colors.white54)),
                    ],
                  ))
                : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isPreviewMode)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.amberAccent, size: 16),
                            SizedBox(width: 8),
                            Text("PREVIEW MODE", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    _buildGoalChips(),
                    const SizedBox(height: 22),
                    _buildJourneyHeader(),
                    const SizedBox(height: 24),
                    _buildMasterplanLabel(),
                    const SizedBox(height: 12),
                    ..._phases.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPhaseCard(p),
                        )),
                    if (_isPreviewMode) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Signal confirmation back to chat or home
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("I LIKE THIS PLAN - START JOURNEY"),
                      ),
                    ],
                    const SizedBox(height: 4),
                    _buildPomplinSaysCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_goals.length, (i) {
          final active = _selectedGoalIdx == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _goals.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGoalIdx = i;
                  _parseRoadmap(_goals[i]);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF2A2A2A) : Colors.transparent,
                  border: Border.all(
                    color: active ? const Color(0xFF444444) : const Color(0xFF333333),
                    width: 1.3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _goals[i]['title'],
                  style: TextStyle(
                    color: active ? Colors.white : _grey,
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildJourneyHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The Journey',
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w400, fontFamily: 'Georgia', height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                _goals[_selectedGoalIdx]['title'],
                style: const TextStyle(color: Colors.white, fontSize: 28, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300, fontFamily: 'Georgia'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 160, height: 180, child: Image.asset('assets/pomplin_reading.png', fit: BoxFit.contain)),
      ],
    );
  }

  Widget _buildMasterplanLabel() => const Text('THE MASTERPLAN', style: TextStyle(color: Color(0xFF666666), fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.w600));

  Widget _buildPhaseCard(RoadmapPhase phase) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(phase.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                _buildStatusBadge(phase.status),
              ],
            ),
          ),
          ...List.generate(phase.tasks.length, (i) {
            final task = phase.tasks[i];
            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: _divider, indent: 16, endIndent: 16),
                _buildTaskRow(task, phase.status, phase.lockedSubtitle),
                if (i == phase.tasks.length - 1) const SizedBox(height: 6),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PhaseStatus status) {
    switch (status) {
      case PhaseStatus.completed: return Text('COMPLETED', style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8));
      case PhaseStatus.active: return Text('ACTIVE', style: TextStyle(color: _yellowGreen, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8));
      case PhaseStatus.locked: return Row(children: [Text('LOCKED', style: TextStyle(color: _grey, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)), const SizedBox(width: 6), Icon(Icons.lock_outline_rounded, color: _grey, size: 14)]);
    }
  }

  Widget _buildTaskRow(RoadmapTask task, PhaseStatus phaseStatus, String? lockedSubtitle) {
    final isLocked = phaseStatus == PhaseStatus.locked;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          _buildTaskIcon(task.done, isLocked),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: TextStyle(color: isLocked ? _grey : Colors.white, fontSize: 15)), if (isLocked && lockedSubtitle != null) ...[const SizedBox(height: 3), Text(lockedSubtitle, style: const TextStyle(color: Color(0xFF555555), fontSize: 12))]])),
          if (task.mascotAsset != null) SizedBox(width: 60, height: 60, child: Image.asset(task.mascotAsset!, fit: BoxFit.contain)),
        ],
      ),
    );
  }

  Widget _buildTaskIcon(bool done, bool locked) {
    if (locked) return Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF444444), width: 1.5), color: const Color(0xFF1E1E1E)), child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF555555), size: 14));
    return AnimatedContainer(duration: const Duration(milliseconds: 200), width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Colors.white : Colors.transparent, border: Border.all(color: done ? Colors.white : const Color(0xFF555555), width: 1.8)), child: done ? const Icon(Icons.check_rounded, color: Colors.black, size: 17) : null);
  }

  Widget _buildPomplinSaysCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 20, 16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          SizedBox(width: 120, height: 120, child: Image.asset('assets/pomplin_idea.png', fit: BoxFit.contain)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('POMPLIN SAYS', style: TextStyle(color: _yellowGreen, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8)), const SizedBox(height: 8), const Text('Stay focused on your journey. Every step counts!', style: TextStyle(color: Colors.white, fontSize: 15, fontStyle: FontStyle.italic, fontFamily: 'Georgia', height: 1.5))])),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [_NavItem(icon: Icons.home_rounded, label: 'Home'), _NavItem(icon: Icons.swap_horiz_rounded, label: 'Roadmap'), _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'), _NavItem(icon: Icons.description_outlined, label: 'Community')];
    return Container(
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final active = _selectedNav == i;
                return GestureDetector(
                  onTap: () {
                    if (i == 0) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                    else if (i == 2) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                    setState(() => _selectedNav = i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 5, height: 5, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: active ? Colors.white : Colors.transparent)), Icon(items[i].icon, color: active ? Colors.white : const Color(0xFF666666), size: 24), const SizedBox(height: 4), Text(items[i].label, style: TextStyle(color: active ? Colors.white : const Color(0xFF666666), fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400))]),
                  ),
                );
              }),
            ),
          ),
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Pomplin · clarity through discipline', style: TextStyle(color: Color(0xFF444444), fontSize: 12, fontStyle: FontStyle.italic, fontFamily: 'Georgia'))),
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