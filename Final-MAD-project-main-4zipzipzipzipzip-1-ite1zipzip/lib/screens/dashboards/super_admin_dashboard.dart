import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_database_service.dart';
import '../../models/user_model.dart';
import '../profile_screen.dart';
import '../landing_screen.dart';
import '../../widgets/ai_chatbot_widget.dart';
import 'tabs/admin_analytics_tab.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _fdb = FirebaseDatabaseService();
  bool _redirecting = false;
  late TabController _tabCtrl;

  StreamSubscription? _usersSub;
  StreamSubscription? _eventsSub;
  StreamSubscription? _bookingsSub;
  StreamSubscription? _analyticsSub;

  List<Map<String, dynamic>> _liveAnalytics = [];
  int _liveEventCount = 0;
  int _liveBookingCount = 0;

  static const _tabs = ['Overview', 'Users', 'Analytics', 'Activity'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _guardAuth();
    _subscribeFirebase();
  }

  void _subscribeFirebase() {
    _usersSub = _fdb.streamUsers().listen((_) {
      if (mounted) setState(() {});
    });
    _eventsSub = _fdb.streamEvents().listen((evts) {
      if (!mounted) return;
      _liveEventCount = evts.length;
      for (final ev in evts) {
        final exists = _auth.allEvents.any((e) => e['id'] == ev['id']);
        if (!exists) {
          final out = Map<String, dynamic>.from(ev);
          for (final k in ['start', 'end', 'createdAt']) {
            if (out[k] is int) out[k] = DateTime.fromMillisecondsSinceEpoch(out[k] as int);
          }
          _auth.seedEvents([out]);
        }
      }
      if (mounted) setState(() {});
    });
    _bookingsSub = _fdb.streamBookings().listen((bks) {
      if (!mounted) return;
      _liveBookingCount = bks.length;
      for (final bk in bks) {
        final exists = _auth.allBookings.any((b) => b['id'] == bk['id']);
        if (!exists) {
          final out = Map<String, dynamic>.from(bk);
          for (final k in ['start', 'end', 'createdAt']) {
            if (out[k] is int) out[k] = DateTime.fromMillisecondsSinceEpoch(out[k] as int);
          }
          _auth.seedBookings([out]);
        }
      }
      if (mounted) setState(() {});
    });
    _analyticsSub = _fdb.streamAnalyticsEvents().listen((events) {
      if (mounted) setState(() => _liveAnalytics = events);
    });
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _eventsSub?.cancel();
    _bookingsSub?.cancel();
    _analyticsSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _guardAuth() {
    final user = _auth.currentUser;
    if (_redirecting) return;
    if (user == null || user.role != UserRole.superAdmin) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LandingScreen()),
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFC46A3D), size: 22),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Super Admin',
                    style: TextStyle(
                        color: Color(0xFF1F1A17),
                        fontWeight: FontWeight.w700,
                        fontSize: 17)),
                Text('Platform Control Centre',
                    style: TextStyle(color: Color(0xFF6E6258), fontSize: 11)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE9E1D6)))),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFFC46A3D),
              unselectedLabelColor: const Color(0xFFA09489),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Color(0xFFC46A3D), width: 2.5)),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: _tabs.map((t) => Tab(height: 40, text: t)).toList(),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF1F1A17)),
            onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()))
                .then((_) => setState(() {})),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF1F1A17)),
            tooltip: 'Logout',
            onPressed: () {
              _auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LandingScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabCtrl,
            children: [
              _buildOverviewTab(user),
              _buildUsersTab(user),
              _buildAnalyticsTab(),
              _buildActivityTab(),
            ],
          ),
          const AiChatbotWidget(),
        ],
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab(UserModel user) {
    final allUsers = _auth.allUsers;
    final organizers = allUsers.where((u) => u.role == UserRole.organizer).length;
    final staff = allUsers.where((u) => u.role == UserRole.staff).length;
    final attendees = allUsers.where((u) => u.role == UserRole.attendee).length;
    final events = _auth.allEvents;
    final bookings = _auth.allBookings;
    final publishedEvents = events.where((e) => e['status'] == 'published').length;
    final activeBookings = bookings.where((b) => b['status'] != 'cancelled').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back, ${user.fullName.split(' ').first}!',
              style: const TextStyle(
                  color: Color(0xFF1F1A17),
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Here\'s what\'s happening across EventFlow',
              style: TextStyle(color: Color(0xFF6E6258), fontSize: 14)),
          const SizedBox(height: 24),

          // ── Live indicator ──────────────────────────────────
          _liveChip(),
          const SizedBox(height: 20),

          // ── Primary Stats ───────────────────────────────────
          const _SectionHeader('Platform Statistics'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _statCard('Total Users', '${allUsers.length}',
                  Icons.people_outline, const Color(0xFF5A6F8C), '+${allUsers.length} registered'),
              _statCard('Live Events', '$publishedEvents',
                  Icons.event_outlined, const Color(0xFF3D7A5A), '${events.length} total'),
              _statCard('Active Bookings', '$activeBookings',
                  Icons.meeting_room_outlined, const Color(0xFFC46A3D), '${bookings.length} total'),
              _statCard('AI Interactions', '${_liveAnalytics.length}',
                  Icons.smart_toy_outlined, const Color(0xFFB7791F), 'Tracked events'),
            ],
          ),
          const SizedBox(height: 24),

          // ── Role Breakdown ──────────────────────────────────
          const _SectionHeader('User Role Breakdown'),
          const SizedBox(height: 12),
          _roleBreakdownCard(organizers, staff, attendees, allUsers.length),
          const SizedBox(height: 24),

          // ── Event Status ────────────────────────────────────
          const _SectionHeader('Event Status Overview'),
          const SizedBox(height: 12),
          _eventStatusCard(events),
          const SizedBox(height: 24),

          // ── Recent Activity ──────────────────────────────────
          const _SectionHeader('Recent Platform Activity'),
          const SizedBox(height: 12),
          ..._recentActivity().take(5).map((a) => _activityTile(a)),
        ],
      ),
    );
  }

  Widget _liveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFF4CAF50), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('Live — Firebase Realtime Database Connected',
              style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(sub,
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF1F1A17), fontSize: 26, fontWeight: FontWeight.w800,
                      letterSpacing: -0.8)),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFFA09489), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleBreakdownCard(int org, int staff, int att, int total) {
    final roles = [
      _RoleBar('Organizers', org, total, const Color(0xFF5A6F8C), Icons.campaign_outlined),
      _RoleBar('Venue Owners', staff, total, const Color(0xFFC46A3D), Icons.apartment_outlined),
      _RoleBar('Attendees', att, total, const Color(0xFF3D7A5A), Icons.confirmation_number_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Column(
        children: roles.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: r.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(r.icon, color: r.color, size: 14),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(r.label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1F1A17))),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.total == 0 ? 0 : r.count / r.total,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF0EBE5),
                    color: r.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${r.count}',
                  style: TextStyle(
                      color: r.color, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _eventStatusCard(List<Map<String, dynamic>> events) {
    final draft = events.where((e) => e['status'] == 'draft').length;
    final published = events.where((e) => e['status'] == 'published').length;
    final now = DateTime.now();
    final completed = events.where((e) {
      final end = e['end'];
      return end is DateTime && end.isBefore(now) && e['status'] == 'published';
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Row(
        children: [
          _statusDot('Draft', draft, const Color(0xFFB7791F)),
          const SizedBox(width: 4),
          _statusDot('Published', published, const Color(0xFF3D7A5A)),
          const SizedBox(width: 4),
          _statusDot('Completed', completed, const Color(0xFF6E6258)),
        ].map((w) => Expanded(child: w)).toList(),
      ),
    );
  }

  Widget _statusDot(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$count',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFF6E6258), fontSize: 11)),
      ],
    );
  }

  List<Map<String, dynamic>> _recentActivity() {
    final activities = <Map<String, dynamic>>[];
    for (final ev in _auth.allEvents.take(3)) {
      activities.add({
        'icon': Icons.event_outlined,
        'color': const Color(0xFF1565C0),
        'title': 'Event: ${ev['title'] ?? 'Untitled'}',
        'sub': 'Status: ${ev['status'] ?? 'draft'}',
        'time': ev['createdAt'] is DateTime
            ? _fmt(ev['createdAt'] as DateTime)
            : 'Recently',
      });
    }
    for (final bk in _auth.allBookings.take(2)) {
      activities.add({
        'icon': Icons.meeting_room_outlined,
        'color': const Color(0xFF6A1B9A),
        'title': 'Booking: ${bk['id']?.toString().substring(0, 8) ?? ''}',
        'sub': 'Status: ${bk['status'] ?? 'pending'}',
        'time': bk['createdAt'] is DateTime
            ? _fmt(bk['createdAt'] as DateTime)
            : 'Recently',
      });
    }
    return activities;
  }

  Widget _activityTile(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (a['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['title'] as String,
                    style: const TextStyle(
                        color: Color(0xFF1F1A17),
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(a['sub'] as String,
                    style: const TextStyle(color: Color(0xFF6E6258), fontSize: 11)),
              ],
            ),
          ),
          Text(a['time'] as String,
              style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
        ],
      ),
    );
  }

  // ── Users Tab ─────────────────────────────────────────────────────────────

  Widget _buildUsersTab(UserModel currentUser) {
    final allUsers = _auth.allUsers;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader('All Users'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${allUsers.length} total',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...allUsers.map((u) => _userTile(u, canDelete: u.id != currentUser.id)),
        ],
      ),
    );
  }

  // ── Analytics Tab ─────────────────────────────────────────────────────────

  Widget _buildAnalyticsTab() => const AdminAnalyticsTab();

  Widget _analyticsCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF1F1A17),
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _barChart(Map<String, int> data, List<Color> colors) {
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b).toDouble();
    final entries = data.entries.toList();
    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal == 0 ? 10 : maxVal * 1.3,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < entries.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(entries[i].key,
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF6E6258))),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, m) => Text('${v.toInt()}',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9E9E9E))))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            entries.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.toDouble(),
                  color: colors[i % colors.length],
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingStatusChart(Map<String, int> data) {
    final colors = [
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFF546E7A),
    ];
    final entries = data.entries.toList();
    final total = data.values.fold(0, (a, b) => a + b);
    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: List.generate(
                entries.length,
                (i) => PieChartSectionData(
                  value: entries[i].value.toDouble(),
                  color: colors[i],
                  radius: 28,
                  showTitle: false,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              entries.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: colors[i], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(entries[i].key,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF1F1A17))),
                    const Spacer(),
                    Text(
                      total == 0
                          ? '0%'
                          : '${(entries[i].value / total * 100).round()}%',
                      style: TextStyle(
                          color: colors[i],
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF6E6258), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF1F1A17),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ── Activity Tab ──────────────────────────────────────────────────────────

  Widget _buildActivityTab() {
    final activityItems = <Map<String, dynamic>>[];

    for (final ev in _liveAnalytics.reversed.take(20)) {
      activityItems.add({
        'icon': Icons.analytics_outlined,
        'color': const Color(0xFF5A6F8C),
        'title': ev['eventName']?.toString() ?? 'Analytics event',
        'sub': 'User: ${ev['userId']?.toString().substring(0, 6) ?? '?'} · Role: ${ev['userRole'] ?? '?'}',
        'time': ev['timestamp'] is int
            ? _fmt(DateTime.fromMillisecondsSinceEpoch(ev['timestamp'] as int))
            : 'Recently',
      });
    }

    for (final ev in _auth.allEvents.take(5)) {
      activityItems.add({
        'icon': Icons.event_outlined,
        'color': const Color(0xFF3D7A5A),
        'title': 'Event created: ${ev['title'] ?? 'Untitled'}',
        'sub': 'Organizer ID: ${ev['organizerId']?.toString().substring(0, 6) ?? '?'}',
        'time': ev['createdAt'] is DateTime ? _fmt(ev['createdAt'] as DateTime) : 'Recently',
      });
    }

    for (final bk in _auth.allBookings.take(5)) {
      activityItems.add({
        'icon': Icons.meeting_room_outlined,
        'color': const Color(0xFFC46A3D),
        'title': 'Booking ${bk['status'] ?? 'created'}',
        'sub': 'Room: ${bk['roomId']?.toString().substring(0, 6) ?? '?'}',
        'time': bk['createdAt'] is DateTime ? _fmt(bk['createdAt'] as DateTime) : 'Recently',
      });
    }

    return activityItems.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline_outlined, size: 48, color: Color(0xFFCCCCCC)),
                SizedBox(height: 12),
                Text('No activity recorded yet',
                    style: TextStyle(color: Color(0xFF9E9E9E))),
                SizedBox(height: 4),
                Text('Activity will appear here as users interact with the platform',
                    style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: activityItems.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionHeader('Platform Activity Log'),
                      _liveChip(),
                    ],
                  ),
                );
              }
              return _activityTile(activityItems[i - 1]);
            },
          );
  }

  // ── User Tile ─────────────────────────────────────────────────────────────

  Widget _userTile(UserModel u, {required bool canDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _roleColor(u.role).withOpacity(0.12),
            child: Text(
              u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
              style: TextStyle(
                  color: _roleColor(u.role), fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName,
                    style: const TextStyle(
                        color: Color(0xFF1F1A17),
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(u.email,
                    style: const TextStyle(
                        color: Color(0xFF6E6258), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showRoleChangeDialog(u),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _roleColor(u.role).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _roleColor(u.role).withOpacity(0.4)),
              ),
              child: Text(
                u.role.displayName,
                style: TextStyle(
                    color: _roleColor(u.role),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (canDelete) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(u),
            ),
          ],
        ],
      ),
    );
  }

  void _showRoleChangeDialog(UserModel u) {
    UserRole selected = u.role;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Role: ${u.fullName}',
              style: const TextStyle(color: Color(0xFF1F1A17), fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
              return RadioListTile<UserRole>(
                value: role,
                groupValue: selected,
                title: Text(role.displayName,
                    style: const TextStyle(color: Color(0xFF1F1A17))),
                activeColor: const Color(0xFFC46A3D),
                onChanged: (v) => setS(() => selected = v!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF6E6258)))),
            ElevatedButton(
              onPressed: () {
                _auth.changeUserRole(u.id, selected);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(UserModel u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User',
            style: TextStyle(color: Color(0xFF1F1A17))),
        content: Text(
            'Are you sure you want to delete "${u.fullName}"? This cannot be undone.',
            style: const TextStyle(color: Color(0xFF6E6258))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6E6258)))),
          ElevatedButton(
            onPressed: () {
              _auth.deleteUser(u.id);
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return const Color(0xFFC46A3D);
      case UserRole.organizer:
        return const Color(0xFF5A6F8C);
      case UserRole.staff:
        return const Color(0xFFC46A3D);
      case UserRole.attendee:
        return const Color(0xFF3D7A5A);
    }
  }

  String _fmt(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]}';
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF1F1A17),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2));
  }
}

class _RoleBar {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  const _RoleBar(this.label, this.count, this.total, this.color, this.icon);
}
